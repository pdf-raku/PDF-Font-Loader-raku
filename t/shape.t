use Test;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

my PDF::Lite $pdf .= new;
$pdf.add-page.text: -> $gfx {
    $gfx.text-position = 10, 700;
    for <Vera.ttf DejaVuSans.ttf TimesNewRomPS.pfa Cantarell-Oblique.otf> {
        for <win identity-h> -> $enc {
            my $file = 't/fonts/' ~ $_;
            next if $enc eq 'identity-h' && $_ ~~ 'EBGaramond12.otc'|'TimesNewRomPS.pfa'|'Cantarell-Oblique.otf';
            my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$file, :$enc;
            $gfx.font = $font;
            $gfx.say: ('flAVX', $file, $enc).join(' '), :shape;
        }
     }
}

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok {
    $pdf.save-as: "t/shape.pdf";
}

done-testing;
