use Test;
plan 30;
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
    my @keys = 'F1'..'F6';
    is-deeply %fonts.keys.sort, @keys.List;
    for @keys  {
        my $dict = %fonts{$_};
        my Bool $core-font = PDF::Font::Loader::Dict.is-core-font: :$dict;
        ok $core-font == ($_ eq 'F6');
        my Bool $embed = PDF::Font::Loader::Dict.is-embedded: :$dict;
        ok $embed == ($_ !~~ 'F3'|'F4'|'F6'),  $_ ~ ' is embedded';
        my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$dict, :$core-font, :$embed, :quiet;
        ok $font.is-core-font == $core-font;
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
my $basename := "t/reuse-type1";
$pdf.id = "{$basename}.t".fmt('%-16s').substr(0,16);
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

done-testing;
