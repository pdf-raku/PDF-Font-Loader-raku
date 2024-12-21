use Test;
plan 3;
use PDF::COS::Dict;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

my PDF::Lite $pdf .= open: "t/fontobj.pdf";

my PDF::Lite::Page $page = $pdf.page(2);

$pdf.page(2).gfx.text: -> $gfx {
    my PDF::COS::Dict %fonts = $gfx.resources('Font');
    $gfx.text-position = 10, 400;
    subtest 'unembedded non-core' => {
        plan 7;
        my PDF::Content::FontObj $f3 = PDF::Font::Loader.load-font: :dict(%fonts<F3>), :quiet;
        is $f3.font-name, 'SitkaSmall', 'font name';
        is $f3.enc, 'win', 'enc';
        nok $f3.is-core-font, "isn't core-font";
        nok $f3.is-embedded, 'is embedded';
        nok $f3.is-subset, "isn't subset";
        nok $f3.encoder.core-metrics.defined, 'lacks core metrics';
        lives-ok {
            $gfx.font = $f3;
            $gfx.say: "reused " ~ $f3.font-name;
            $gfx.say: "abcxyzABCXYZ";
        }, 'reuse unembedded font';
    }
    subtest 'unembedded core-font' => {
        plan 8;
        my PDF::Content::FontObj $f6 = PDF::Font::Loader.load-font: :dict(%fonts<F6>), :quiet;
        is $f6.font-name, 'Times-Roman', 'font name';
        ok $f6.is-core-font, "is core-font";
        is $f6.enc, 'win', 'enc';
        nok $f6.is-embedded, 'is embedded';
        nok $f6.is-subset, "isn't subset";
        ok $f6.encoder.core-metrics.defined, 'has core metrics';
        is $f6.encoder.core-metrics.stringwidth('Raku'), 2111, 'sample core metrics';
        lives-ok {
            $gfx.font = $f6;
            $gfx.say: "reused " ~ $f6.font-name;
            $gfx.say: "abcxyzABCXYZ";
        }, 'reuse core font';
    }
}
my $basename := "t/reuse-unembedded";
$pdf.id =  "{$basename}.t".fmt('%-16s').substr(0,16);
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

done-testing;
