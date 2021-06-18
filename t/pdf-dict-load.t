use v6;
use Test;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

plan 5;
# see if we can re-load the font that we wrote in pdf-text.align.t

class FontLoader {
    # load fonts from a rendering class
    # this seems like the most likely way this loader will be used
    # in practice; load fonts from a PDF as they are referenced
    use PDF::Content::Ops :OpCode;
    has Bool %!seen{Any};

    # intercept just the SetFont Graphics operation
    method callback{
        sub ($op, *@args) {
            my $method = OpCode($op).key;
            self."$method"(|@args)
                if $method ~~ 'SetFont';
        }
    }
    method render($content) {
        my &callback = self.callback;
        $content.render(:&callback);
    }
    method SetFont(Str $font-key, Numeric $font-size) {
        with $*gfx.resource-entry('Font', $font-key) -> $dict {
            take PDF::Font::Loader.load-font: :$dict
               unless %!seen{$dict}++;
        }
    }
}

my PDF::Lite $pdf .= open: "t/pdf-text-align.pdf";
my PDF::Content::FontObj $f;
for gather FontLoader.new.render: $pdf.page(1) -> PDF::Content::FontObj $font {
    $f = $font;
    # a few sanity checks
    isa-ok $font, 'PDF::Font::Loader::FreeType', 'loaded a FreeType font';
    like $font.font-name, /^[<[A..Z]>**6'+']?'DejaVuSans'$/, 'font name';
    ok( 1100 < $font.height < 1900, 'font height')
        or diag "unexpected font height: {$font.height}";
    # first few characters in the subset
    my $text = "Abc♠♥♦♣b";
    my $enc = $font.encode($text, :str);
    is-deeply $enc, [~]("\0\x[24]", "\0\x[45]", "\0\x[46]", "\x[F]\x[38]", "\x[F]\x[3d]", "\x[F]\x[3e]", "\x[F]\x[3b]", "\0\x[45]");
    is $font.decode($enc, :str), $text, "font encode/decode round-trip";
}
$pdf.add-page.graphics: {
    .font = $f;
    .say: "here goes nothing", :position[10,20];
}
$pdf.save-as: "/tmp/out.pdf";
done-testing;
