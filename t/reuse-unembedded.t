use Test;
plan 2;
use PDF::COS::Dict;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

my PDF::Lite $pdf .= open: "t/fontobj.pdf";

my PDF::Lite::Page $page = $pdf.page(2);

$pdf.page(2).gfx.text: -> $gfx {
    my PDF::COS::Dict %fonts = $gfx.resources('Font');
    my PDF::Content::FontObj $f3 = PDF::Font::Loader.load-font: :dict(%fonts<F3>), :quiet;
    $gfx.text-position = 10, 400;
    subtest 'unembedded non-core' => {
        plan 5;
        is $f3.font-name, 'WenQuanYiMicroHei', 'font name';
        is $f3.enc, 'win', 'enc';
        nok $f3.is-embedded, 'is embedded';
        nok $f3.is-subset, "isn't subset";
        lives-ok {
            $gfx.font = $f3;
            $gfx.say: "reused " ~ $f3.font-name;
            $gfx.say: "abcxyzABCXYZ";
        }, 'reuse unembedded font';
    }
    subtest 'unembedded core-font' => {
        plan 5;
        my PDF::Content::FontObj $f4 = PDF::Font::Loader.load-font: :dict(%fonts<F4>), :quiet;
        is $f4.font-name, 'Times-Roman', 'font name';
        is $f4.enc, 'win', 'enc';
        nok $f4.is-embedded, 'is embedded';
        nok $f4.is-subset, "isn't subset";
        lives-ok {
            $gfx.font = $f4;
            $gfx.say: "reused " ~ $f4.font-name;
            $gfx.say: "abcxyzABCXYZ";
        }, 'reuse core font';
    }
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16.16s');

$pdf.save-as: "t/reuse-unembedded.pdf";

done-testing;