use Test;
plan 3;

use PDF::Lite;
use PDF::Font::Loader :&load-font;
use PDF::Font::Loader::Glyph;
use PDF::Content::FontObj;

my constant Glyph = PDF::Font::Loader::Glyph;

try {require HarfBuzz::Subset;}
if $! {
    skip-rest 'HarfBuzz::Subset required to run subset tests';
    exit;
}

given load-font( :file<t/fonts/Vera.ttf>, :subset) {
   # since the remaining tests hard-code the prefix
   like .font-name, /^<[A..Z]>**6 '+BitstreamVeraSans-Roman'$/, 'font prefix generation';
}

# Try various fonts and encodings

my PDF::Content::FontObj $ttf-font = load-font( :file<t/fonts/Vera.ttf>, :subset, :prefix<XBCDEF>);
my PDF::Content::FontObj $otf-font = load-font( :file<t/fonts/Cantarell-Oblique.otf>, :enc<win>, :subset, :prefix<YBCDEF>);
my PDF::Content::FontObj $ttc-font = load-font( :file<t/fonts/Sitka.ttc>, :subset, :prefix<ZBCDEF>);

sub check-fonts($whence) {
    subtest $whence => {
        plan 17;
        ok $ttf-font.is-subset, '$ttf-font.is-subset';
        like $ttf-font.font-name, /^<[A..Z]>**6 '+BitstreamVeraSans-Roman'$/, 'font-name';
        is $ttf-font.encoding, 'Identity-H', '$ttf-font.encoding';
        my Glyph @shape = $ttf-font.get-glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:name<A>, :code-point(65), :cid(36), :gid(36), :ax(684), :sx(684), :ay(0)), 'ttf-font glyph "A"';
        is-deeply @shape.tail, Glyph.new(:name<b>, :code-point(98), :cid(69), :gid(69), :ax(635), :sx(635), :ay(0)), 'ttf-font glyph "b"';

        ok $otf-font.is-subset, '$otf-font.is-subset';
        like $otf-font.font-name, /^<[A..Z]>**6 '+Cantarell-Oblique'$/, 'font-name';
        is $otf-font.encoding, 'WinAnsiEncoding', '$otf-font.encoding';
        @shape = $otf-font.get-glyphs("Ab");
        # CIDs change, after reloading font face
        is @shape.head.code-point, 'A'.ord, 'otf-font glyph "A" code-point';
        is @shape.head.ax, 575, 'otf-font glyph "A" ax';
        is @shape.tail.code-point, 'b'.ord, 'otf-font glyph "b" code-point';
        is @shape.tail.ax, 535, 'otf-font glyph "b" ax';

        ok $ttc-font.is-subset, '$ttc-font.is-subset';
        like $ttc-font.font-name, /^<[A..Z]>**6 '+SitkaSmall'$/, 'font-name';
        is $ttc-font.encoding, 'Identity-H', '$ttc-font.encoding';
        @shape = $ttc-font.get-glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:name<A>, :code-point(65), :cid(4), :gid(4), :ax(689), :sx(689) :ay(0)), 'ttc-font glyph "A"';
        is-deeply @shape.tail, Glyph.new(:name<b>, :code-point(98), :cid(179), :gid(179), :ax(615), :sx(615), :ay(0)), 'ttc-font glyph "b"';

    }
}

my PDF::Lite $pdf .= new;

$pdf.add-page.gfx.text: {
    .text-position = 10, 650;
    .font = $ttf-font;
    .say: "ttf font { $ttf-font.font-name } {$ttf-font.encoding} subset ABCxyz";
    .say: '';
    .font = $otf-font;
    .say: "otf font { $otf-font.font-name } {$otf-font.encoding} subset ABCxyz";
    .say: '';
    .font = $ttc-font;
    .say: "ttc font { $ttc-font.font-name } {$ttc-font.encoding} subset ABCxyz";
}

check-fonts('created fonts');

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/subset.pdf";

# check our subsets survive serialization;
$pdf .= open: "t/subset.pdf";

my %fonts = $pdf.page(1).resources('Font');
$ttf-font = load-font( dict => %fonts<F1> );
$otf-font = load-font( dict => %fonts<F2> );
$ttc-font = load-font( dict => %fonts<F3> );

check-fonts('re-read fonts');

done-testing;
