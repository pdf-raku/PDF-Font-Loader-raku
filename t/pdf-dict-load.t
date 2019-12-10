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
    has %.fonts;

    # intercept just the SetFont Graphics operation
    method callback{
        sub ($op, *@args) {
            my $method = OpCode($op).key;
            self."$method"(|@args)
                if $method ~~ 'SetFont';
        }
    }
    method render($content) {
        my $obj = self.new();
        my &callback = $obj.callback;
        $content.render(:&callback);
        # return fonts
        $obj.fonts;
    }
    method SetFont(Str $font-key, Numeric $font-size) {
        with $*gfx.resource-entry('Font', $font-key) -> $dict {
            %!fonts{$dict.obj-num} //= PDF::Font::Loader.load-font: :$dict;
        }
        else {
            warn "unable to locate Font in resource dictionary: $font-key";
        }
    }
}

my PDF::Lite $pdf .= open: "t/pdf-text-align.pdf";

my %fonts = FontLoader.render: $pdf.page(1);
# actually only one
my ($font) = %fonts.values;

# a few sanity checks
isa-ok $font, 'PDF::Font::Loader::FreeType', 'loaded a FreeType font';
is $font.font-name, 'DejaVuSans';
is-approx $font.height, 1695.3125;
my $text = "Abc♠♥♦♣";
my $enc = $font.encode($text, :str);
is $enc, "\0\$\0E\0F\x[F]8\x[F]=\x[F]>\x[F];", 'encode (identity-h)';
is $font.decode($enc, :str), $text, "font encode/decode round-trip";

done-testing;
