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
has PDF::COS::Stream $.cmap is rw;
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
method set-width($cid, $width) {
    my $fc = self.first-char($cid);
    @!widths[$cid - $fc] ||= do {
        $!widths-updated = True;
        $width;
    }
}

method glyph(UInt $cid) {
    my uint32 $code-point = $.to-unicode[$cid] || 0;
    my FT_UInt $gid = @!cid-to-gid-map[$cid]
        if @!cid-to-gid-map;
    $gid ||= $code-point
        ?? $.face.glyph-index($code-point)
        !! $cid;
    my $dx = self!glyph-size($gid)[Width].round;
    $.set-width($cid, $dx);
    my str $name;
    if $code-point {
        my $chr := $code-point.chr;
        $name = %Font::AFM::Glyphs{$chr} // $chr.uniname.lc;
    }
    else {
        $name = $_ with $.face.glyph-name-from-index($gid);
    }
    PDF::Font::Loader::Glyph.new: :$name, :$code-point, :$cid, :$gid, :$dx;
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

# may be overridden
method make-cmap-content(:$to-unicode = self.to-unicode) {
    my @cmap-char;
    my @cmap-range;
    my $d = (self.is-wide ?? '4' !! '2');
    my \cid-fmt   := '<%%0%sX>'.sprintf: $d;
    my \char-fmt  := '<%%0%sX> <%%04X>'.sprintf: $d;
    my \range-fmt := cid-fmt ~ ' ' ~ char-fmt;
    my \last-char := $.last-char;

    loop (my uint16 $cid = $.first-char; $cid <= last-char; $cid++) {
        my uint32 $ord = $to-unicode[$cid]
          || next;
        my uint16 $start-cid = $cid;
        my uint32 $start-code = $ord;
        while $cid < last-char && $to-unicode[$cid + 1] == $ord+1 {
            $cid++; $ord++;
        }
        if $start-cid == $cid {
            @cmap-char.push: char-fmt.sprintf($cid, $start-code);
        }
        else {
            @cmap-range.push: range-fmt.sprintf($start-cid, $cid, $start-code);
        }
    }

    my @content = "1 begincodespacerange {$.first-char.fmt(cid-fmt)} {last-char.fmt(cid-fmt)} endcodespacerange";

    if @cmap-char {
        @content.push: "{+@cmap-char} beginbfchar";
        @content.append: @cmap-char;
        @content.push: 'endbfchar';
    }

    if @cmap-range {
        @content.push: "{+@cmap-range} beginbfrange";
        @content.append: @cmap-range;
        @content.push: 'endbfrange';
    }

    @content.join: "\n";
}

method make-cmap(|c) {
    fail 'unable to serialise without $.cmap'
        without $!cmap;

    my PDF::IO::Writer $writer .= new;
    my $cmap-name = $writer.write: $!cmap<CMapName>.content;
    my $cid-system-info = $writer.write: $!cmap<CIDSystemInfo>.content;

    qq:to<--END-->.chomp;
        %% Custom
        %% CMap
        %%
        /CIDInit /ProcSet findresource begin
        12 dict begin begincmap
        $cid-system-info
        /CMapName $cmap-name def
        {self.make-cmap-content(|c)}
        endcmap CMapName currendict /CMap defineresource pop end end
        --END--
}

=begin pod

=head2 Description

This is the base class for all encoding classes.

=head2 Methods

These methods are common to all encoding sub-clasess

=head3 first-char

The first L<CID|PDF::Font::Loader::Glyph#cid> in the fonts character-set.

=head2 last-char

The last L<CID|PDF::Font::Loader::Glyph#cid> in the fonts character-set.

=head3 widths
=begin code :lang<raku>
method widths() returns Array[Uint]
=end code

The widths of all glyphs, indexed by CID, in the range `first-char` to `last-char`. The widths are in unscaled font units and should be multiplied by
font-size / 1000 to compute actual widths.

=head3 glyph

=begin code :lang<raku>
method glyph(UInt $cid) returns PDF::Font::Loader::Glyph
=end code

Returns a L<Glyph|PDF::Font::Loader::Glyph> object for the given CID index.

=head3 make-cmap

Generates a CMap for inclusion in a PDF. This method is typically called from the font object when an encoding has been added or updated for the encoder.

=end pod
