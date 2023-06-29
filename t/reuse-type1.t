use Test;
plan 20;
use PDF::COS::Dict;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Font::Loader::Dict;
use PDF::Content::FontObj;

my PDF::Lite $pdf .= open: "t/fontobj.pdf";
my PDF::Lite::Page $page = $pdf.page(2);


$pdf.page(2).gfx.text: -> $gfx {
    my PDF::COS::Dict %fonts = $gfx.resources('Font');
    $gfx.text-position = 10, 400;
    is-deeply %fonts.keys.sort, ("F1", "F2", "F3", "F4", "F5");
    for 'F1'..'F5' {
        my $dict = %fonts{$_};
        my Bool $core-font = PDF::Font::Loader::Dict.is-core-font: :$dict;
        ok $core-font == ($_ eq 'F5');
        my Bool $embed = !$core-font;
        my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$dict, :$core-font, :$embed, :quiet;
        ok $font.is-core-font == ($_ eq 'F5');
        if $_ eq 'F1' {
            is $font.font-name, 'Cantarell-Oblique', 'font-name';
            is $font.enc, 'win', 'enc';
            ok $font.is-embedded, 'is embedded';
            nok $font.is-subset, "isn't subset";
            }
        lives-ok {
            $gfx.font = $font;
            $gfx.say: "reused " ~ $font.font-name ~ " abcxyzABCXYZ";
        }, 'reuse font';
    }
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16.16s');

$pdf.save-as: "t/reuse-type1.pdf";

done-testing;
