unit class PDF::Font::Loader::Enc;

use Font::AFM;
use Font::FreeType::Error;
use Font::FreeType::Raw::Defs;
use PDF::Font::Loader::Glyph;

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
