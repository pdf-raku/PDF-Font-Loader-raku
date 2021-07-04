use Test;
plan 2;

use PDF::Lite;
use PDF::Font::Loader :&load-font;
use PDF::Font::Loader::Glyph;
use PDF::Content::FontObj;

my constant Glyph = PDF::Font::Loader::Glyph;

try {require HarfBuzz::Subset;}
if $! {
    skip-rest 'HarfBuzz::Subset required to run canvas tests';
    exit;
}

# Try various fonts and encodings

my PDF::Content::FontObj $ttf-font = load-font( :file<t/fonts/Vera.ttf>, :subset);
my PDF::Content::FontObj $otf-font = load-font( :file<t/fonts/Cantarell-Oblique.otf>, :enc<win>, :subset);
my PDF::Content::FontObj $ttc-font = load-font( :file<t/fonts//wqy-microhei.ttc>, :subset);

sub check-fonts($whence) {
    subtest $whence => {
        plan 11;
        ok $ttf-font.is-subset, '$ttf-font.is-subset';
        like $ttf-font.font-name, /^<[A..Z]>**6 '+BitstreamVeraSans-Roman'$/, 'font-name';
        my Glyph @shape = $ttf-font.glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:code-point(65), :cid(36), :gid(36), :dx(684), :dy(0)), 'ttf-font glyph "A"';

is-deeply @shape.tail, Glyph.new(:code-point(98), :cid(69), :gid(69), :dx(635), :dy(0)), 'ttf-font glyph "b"';
        is $ttf-font.encoding, 'Identity-H', '$ttf-font.encoding';

        ok $otf-font.is-subset, '$otf-font.is-subset';
        like $otf-font.font-name, /^<[A..Z]>**6 '+Cantarell-Oblique'$/, 'font-name';
        is $otf-font.encoding, 'WinAnsiEncoding', '$otf-font.encoding';

        ok $ttc-font.is-subset, '$ttc-font.is-subset';
        like $ttc-font.font-name, /^<[A..Z]>**6 '+WenQuanYiMicroHei'$/, 'font-name';
        is $ttc-font.encoding, 'Identity-H', '$ttc-font.encoding';
    }
}

check-fonts('created fonts');

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
