unit class PDF::Font::Loader::Enc;

use Font::AFM;
use Font::FreeType::Error;
use Font::FreeType::Raw::Defs;
use PDF::Font::Loader::Glyph;
use PDF::IO::Writer;

enum <Width Height>;

has uint16 @.cid-to-gid-map;
has uint $.first-char;
has uint16 @!widths;
has Bool $.widths-updated is rw;
has Bool $.encoding-updated is rw;
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
        $name = $_ with %Font::AFM::Glyphs{$code-point.chr};
    }
    $name ||= $_ with $.face.glyph-name-from-index($gid);
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

method make-cmap-stream(:$dict!, :$font-name!, :$to-unicode = self.to-unicode) {
    my @cmap-char;
    my @cmap-range;

    my $d = (self.is-wide ?? '4' !! '2');
    my \cid-fmt   := '<%%0%sX>'.sprintf: $d;
    my \char-fmt  := '<%%0%sX> <%%04X>'.sprintf: $d;
    my \range-fmt := cid-fmt ~ ' ' ~ char-fmt;
    my \last-char := $.last-char;
    my Str:D $CMapName = $dict<CMapName>;

    loop (my uint16 $cid = $.first-char; $cid <= last-char; $cid++) {
        my uint32 $char-code = $to-unicode[$cid]
          || next;
        my uint16 $start-cid = $cid;
        my uint32 $start-code = $char-code;
        while $cid < last-char && $to-unicode[$cid + 1] == $char-code+1 {
            $cid++; $char-code++;
        }
        if $start-cid == $cid {
            @cmap-char.push: char-fmt.sprintf($cid, $start-code);
        }
        else {
            @cmap-range.push: range-fmt.sprintf($start-cid, $cid, $start-code);
        }
    }

    if @cmap-char {
        @cmap-char.unshift: "{+@cmap-char} beginbfchar";
        @cmap-char.push: 'endbfchar';
    }

    if @cmap-range {
        @cmap-range.unshift: "{+@cmap-range} beginbfrange";
        @cmap-range.push: 'endbfrange';
    }

    my PDF::IO::Writer $writer .= new;
    my $cmap-name = $writer.write: $CMapName.content;
    my $postscript-name = $writer.write: :literal($font-name);

    my $decoded = qq:to<--END-->.chomp;
        %% Custom
        %% CMap
        %%
        /CIDInit /ProcSet findresource begin
        12 dict begin begincmap
        /CIDSystemInfo <<
           /Registry $postscript-name
           /Ordering (XYZ)
           /Supplement 0
        >> def
        /CMapName $cmap-name def
        1 begincodespacerange {$.first-char.fmt(cid-fmt)} {last-char.fmt(cid-fmt)} endcodespacerange
        {@cmap-char.join: "\n"}
        {@cmap-range.join: "\n"}
        endcmap CMapName currendict /CMap defineresource pop end end
        --END--

        PDF::COS::Stream.COERCE: { :$dict, :$decoded };
}
