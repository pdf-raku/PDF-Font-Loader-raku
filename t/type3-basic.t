use Test;
plan 11;
use PDF::COS::Dict;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Font::Loader::Dict;
use PDF::Content::FontObj;
use PDF::Font::Loader::Glyph;
use PDF::Content;

my PDF::Lite $pdf .= open: "t/pdf/font-type3.pdf";

my PDF::Lite::Page $page = $pdf.page(1);

$pdf.page(1).gfx.text: -> $gfx {
    my PDF::COS::Dict %fonts = $gfx.resources('Font');
    $gfx.text-position = 10, 400;
    is-deeply %fonts.keys.sort, ("F1",);
    my $dict = %fonts<F1>;
    my Bool $core-font = PDF::Font::Loader::Dict.is-core-font: :$dict;
    nok $core-font, 'is-core-font';
    my PDF::Content::FontObj $f1 = PDF::Font::Loader.load-font: :$dict, :$core-font;
    nok $f1.is-core-font;
    is $f1.font-name, 'courier', 'font-name';
    is $f1.enc, 'std', 'enc';
    nok $f1.is-embedded, "isn't embedded";
    nok $f1.is-subset, "isn't subset";
    my @cids = 1, 2, 3;
    my @glyphs = $f1.get-glyphs(@cids);
    is-deeply @glyphs[0], PDF::Font::Loader::Glyph.new(:name<square>, :cid(1), :gid(1), :ax(1000), :sx(1000) );
    is $f1.stringwidth(@cids), @glyphs>>.ax.sum;

    lives-ok {
        $gfx.font = $f1;
        $gfx.text-position = 10, 600;
        $gfx.ShowText: "\x1\x2\x3";
    }, 'reuse font';
}

# ensure consistant document ID generation
my $basename := "t/type3-basic";
$pdf.id =  "{$basename}.t".fmt('%-16s').substr(0,16);
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

done-testing;
