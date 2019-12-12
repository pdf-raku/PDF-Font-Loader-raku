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
    is $font.font-name, 'DejaVuSans', 'font name';
    is-approx $font.height, 1695.3125, 'font height';
    my $text = "Abc♠♥♦♣";
    my $enc = $font.encode($text, :str);
    is $enc, "\0\$\0E\0F\x[F]8\x[F]=\x[F]>\x[F];", 'encode (identity-h)';
    is $font.decode($enc, :str), $text, "font encode/decode round-trip";
}

done-testing;
