#| Font encoder/decoder base class
unit class PDF::Font::Loader::Enc;

use Font::AFM;
use Font::FreeType::Error;
use Font::FreeType::Raw::Defs;
use PDF::Font::Loader::Glyph;
use PDF::IO::Writer;
use PDF::COS::Stream;

enum <Width Height>;

has uint16 @.cid-to-gid-map;
has uint $.first-char;
has uint16 @!widths;
has Bool $.widths-updated is rw;
has Bool $.encoding-updated is rw;
has PDF::COS::Stream $.cmap is rw; # /ToUnicode CMap
has Lock $.lock handles<protect> .= new;
submethod TWEAK(:$widths) {
    @!widths = .map(*.Int) with $widths;
}
multi method first-char { $!first-char }
multi method first-char($cid) {
    unless @!widths {
        $!widths-updated = True;
        $!first-char = $cid;
        @!widths = [0];
    }
    if $!first-char > $cid {
        $!widths-updated = True;
        @!widths.prepend: 0 xx ($!first-char - $cid);
        $!first-char = $cid;
    }
    $!first-char;
}

method last-char { $!first-char + @!widths - 1; }

method widths is rw { @!widths }
method is-wide { False  }

multi method width(Int $cid) is rw {
    Proxy.new(
        FETCH => {
            my $idx := $cid - self.first-char;
            0 <= $idx < +@!widths
                ?? @!widths[$idx]
                !! @!widths.of;
        },
        STORE => -> $, Int() $w {
            my $fc = self.first-char($cid);
            @!widths[$cid - $fc] = $w;
            $!widths-updated = True;
    });
}

method to-unicode {...}
method local-glyph-name($cid) {
    # Overridden in PDF::Content::Font::Enc::Glyphic
    PDF::COS::Name
}

method glyph(UInt $cid) {
    my uint32 $code-point = $.to-unicode[$cid] || 0;
    my FT_UInt $gid = @!cid-to-gid-map[$cid]
        if @!cid-to-gid-map;
    $gid ||= $.face.glyph-index($code-point)
        if $code-point;
    $gid ||= $cid;
    my $ax = (self.width($cid) ||= self!glyph-size($gid)[Width].round);
    my Str $name;

    if $code-point {
        # prefer standard names
        my $chr := $code-point.chr;
        $name = %Font::AFM::Glyphs{$chr} // $chr.uniname.lc;
    }
    elsif $.local-glyph-name($cid) -> $_ {
        # try for a dictionary name
        $name = $_;
    }
    elsif try { $.face.glyph-name-from-index($gid) } -> $_ {
        # try for a name from the font program
        $name = $_
             unless .starts-with('.');
    }
    PDF::Font::Loader::Glyph.new: :$name, :$code-point, :$cid, :$gid, :$ax;
}

method !glyph-size($gid) {
    my $struct = $.face.raw;
    my $glyph-slot = $struct.glyph;
    my $scale = 1000 / ($.face.units-per-EM || 1000);
    my int $width  = 0;
    my int $height = 0;

    if $gid {
        CATCH {
            when Font::FreeType::Error { warn "error processing glyph index: {$gid}: " ~ .message; }
        }
        ft-try({ $struct.FT_Load_Glyph( $gid, FT_LOAD_NO_SCALE ); });
        given $glyph-slot.metrics {
            $width  = .hori-advance;
            $height = .vert-advance;
        }
    }

    ($width * $scale, $height * $scale);
}

method has-encoding {
    so @.to-unicode.first: {$_}
}

method make-cmap-codespaces {
    self.is-wide
        ?? ['<0000> <FFFF>']
        !! ['<00> <FF>'];
}

sub code-batches($name, @content) is export(:code-batches) {
    my @lines;
    my int $n = +@content;

    loop (my int $i = 0; $i < $n;) {
        my int $size = min($n - $i, 100);
        my int $end = $i + $size;
        @lines.push: '';
        @lines.push: "{$size} begin" ~ $name;

        loop (my int $j = $i; $j < $end;) {
            @lines.push: @content[$j++];
        }

        @lines.push: 'end' ~ $name;
        $i = $end;
    }

    @lines;
}

sub codepoint-to-hex(UInt $_) {
    my $buf = .chr.encode("utf16");
    my \words = +$buf;
    my $fmt = words > 1 || $buf[0] >= 256 ?? '%04X' !! '%02X';
    my $s = $buf[0].fmt($fmt);
    $buf == words > 1
        ?? $s ~ $buf[1].fmt("%04X") # 4 byte
        !! $s;                      # variable bytes
}

method make-to-unicode-cmap(:$to-unicode = self.to-unicode) {
    my @content;
    my @cmap-char;
    my @cmap-range;
    my \last-char  = $.last-char;
    my \char-fmt  := '<%04X> <%s>';

    loop (my uint16 $cid = $.first-char; $cid <= last-char; $cid++) {
        my uint32 $ord = $to-unicode[$cid]
            || next;
        my uint16 $start-cid = $cid;
        my uint8 $start-byte = $start-cid div 256;
        my uint32 $start-code = $ord;
        while $cid < last-char && $to-unicode[$cid + 1] == $ord+1 && ($cid+1) div 256 == $start-byte {
            $cid++; $ord++;
        }
        my $code-hex = codepoint-to-hex($start-code);

        if $start-cid == $cid && $start-byte == $cid div 256 {
            @cmap-char.push: char-fmt.sprintf($cid, $code-hex);
        }
        else {
            @cmap-range.push: $start-cid.fmt('<%04X> ') ~ char-fmt.sprintf($cid, $code-hex);
        }
    }

    @content.append: code-batches('bfchar', @cmap-char);
    @content.append: code-batches('bfrange', @cmap-range);
    $.make-cmap: $!cmap, @content;
}

method make-cmap(PDF::COS::Stream $cmap, @content, |c) {
    my PDF::IO::Writer $writer .= new;
    my $cmap-name = $writer.write: $cmap<CMapName>.content;
    my $cid-system-info = $writer.write: $!cmap<CIDSystemInfo>.content;
    my @codespaces = code-batches('codespacerange', self.make-cmap-codespaces);

    qq:to<--END-->.chomp;
        %% Custom
        %% CMap
        %%
        /CIDInit /ProcSet findresource begin
        12 dict begin begincmap
        $cid-system-info
        /CMapName $cmap-name def
        {@codespaces.join: "\n";}
        {@content.join: "\n"}
        endcmap CMapName currendict /CMap defineresource pop end end
        --END--
}

=begin pod

=head2 Description

This is the base class for all encoding classes. It is suitable for fixed
length encodings only such as `mac`, `win` (single byte) or `identity-h`.

L< PDF::Font::Loader::Enc::CMap>, which inherits from this class, is the
base class for variable length encodings

=head2 Methods

These methods are common to all encoding sub-classes

=head3 has-encoding

True if the font has a Unicode mapping.

The Unicode encoding layer is optional by design in the PDF standard.

This method should be used on a font loaded from a PDF dictionary to ensure that it
has an character encoding layer and `encode()` and `decode()` methods can be called on it.

=head3 first-char

The first L<CID|PDF::Font::Loader::Glyph#cid> in the fonts character-set.

=head2 last-char

The last L<CID|PDF::Font::Loader::Glyph#cid> in the fonts character-set.

=head3 widths
=begin code :lang<raku>
method widths() returns Array[UInt]
=end code

The widths of all glyphs, indexed by CID, in the range `first-char` to `last-char`. The widths are in unscaled font units and should be multiplied by
font-size / 1000 to compute actual widths.

=head3 width
=begin code :lang<raku>
method width($cid) returns UInt
=end code
R/w accessor to get or sey the width of a character.

=head3 glyph

=begin code :lang<raku>
method glyph(UInt $cid) returns PDF::Font::Loader::Glyph
=end code

Returns a L<Glyph|PDF::Font::Loader::Glyph> object for the given CID index.

=head3 method encode
=begin code :lang<raku>
multi method encode(Str $text, :cids($)!) returns Blob; # encode to CIDs
multi method encode(Str $text) returns PDF::COS::ByteString;            # encode to a byte-string
=end code
Encode a font from a Unicode text string. By default to byte-string.

The `:cids` option returns a Blob of CIDs, rather than a fully encoded bytes-string.

=head3 method decode
=begin code :lang<raku>
multi method decode(Str $byte-string, :cids($)!) returns Seq; # decode to CIDs
multi method decode(Str $byte-string, :ords($)!) returns Seq; # decode to code-points
multi method decode(Str $byte-string) returns PDF::COS::ByteString;            # encode to a byte-string
=end code

Decodes a PDF byte string, by default to a Unicode text string.

=head3 set-encoding
=begin code :lang<raku>
method set-encoding(UInt $code-point, UInt $cid)
=end code

Map a single Unicode code-point to a CID index. This method is most likely
to be useful for manually setting up an encoding layer for a font loaded
from a PDF that lacks an encoding layer(`has-encoding()` is `False`).

=head3 make-to-unicode-cmap

Generates a CMap for the /ToUnicode entry in a PDF font. This method is typically called from the font object when an encoding has been added or updated for the encoder.

=end pod
