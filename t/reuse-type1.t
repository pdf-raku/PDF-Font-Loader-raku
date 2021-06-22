use Test;
plan 6;
use PDF::COS::Dict;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

my PDF::Lite $pdf .= open: "t/freetype.pdf";

my PDF::Lite::Page $page = $pdf.page(2);

$pdf.page(2).gfx.text: -> $gfx {
    my PDF::COS::Dict %fonts = $gfx.resources('Font');
    $gfx.text-position = 10, 400;
    is-deeply %fonts.keys.sort, ("F1", "F2", "F3", "F4");
    my PDF::Content::FontObj $f1 =  PDF::Font::Loader.load-font: :dict(%fonts<F1>), :embed;
    is $f1.font-name, 'Cantarell-Oblique', 'font-name';
    is $f1.enc, 'win', 'enc';
    ok $f1.is-embedded, 'is embedded';
    nok $f1.is-subset, "isn't subset";
    lives-ok {
        $gfx.font = $f1;
        $gfx.say: "reused " ~ $f1.font-name;
        $gfx.say: "abcxyzABCXYZ";
    }, 'reuse font';
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16.16s');

$pdf.save-as: "t/reuse-type1.pdf";

done-testing;