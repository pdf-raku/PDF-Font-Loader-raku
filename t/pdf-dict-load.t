use v6;
use Test;
use PDF::Lite;
use PDF::Font::Loader;

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

for gather FontLoader.new.render: $pdf.page(1) -> $font {
    # a few sanity checks
    isa-ok $font, 'PDF::Font::Loader::FreeType', 'loaded a FreeType font';
    todo "font subsetting";
    like $font.font-name, /^<[A..Z]>**6'+DejaVuSans'$/, 'font name';
    is-approx $font.height, 1695.3125, 'font height';
    # first few characters in the subset
    my $text = "Abc♠♥♦♣b";
    my $enc = $font.encode($text, :str);
    todo "font subsetting";
    is $enc, "\0\x[1]\0\x[2]\0\x[3]\0\x[4]\0\x[5]\0\x[6]\0\x[7]\0\x[2]";
    is $font.decode($enc, :str), $text, "font encode/decode round-trip";
}

done-testing;
