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
my PDF::Content::FontObj $ttc-font = load-font( :file<t/fonts/wqy-microhei.ttc>, :subset);
my PDF::Content::FontObj $uni-font = load-font( :file<t/fonts/DejaVuSans.ttf>,  :enc<utf16>, :subset);

sub check-fonts($whence) {
    subtest $whence => {
        plan 22;
        ok $ttf-font.is-subset, '$ttf-font.is-subset';
        like $ttf-font.font-name, /^<[A..Z]>**6 '+BitstreamVeraSans-Roman'$/, 'font-name';
        is $ttf-font.encoding, 'Identity-H', '$ttf-font.encoding';
        my Glyph @shape = $ttf-font.glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:name<A>, :code-point(65), :cid(36), :gid(36), :dx(684), :dy(0)), 'ttf-font glyph "A"';
        is-deeply @shape.tail, Glyph.new(:name<b>, :code-point(98), :cid(69), :gid(69), :dx(635), :dy(0)), 'ttf-font glyph "b"';

        ok $otf-font.is-subset, '$otf-font.is-subset';
        like $otf-font.font-name, /^<[A..Z]>**6 '+Cantarell-Oblique'$/, 'font-name';
        is $otf-font.encoding, 'WinAnsiEncoding', '$otf-font.encoding';
        @shape = $otf-font.glyphs("Ab");
        # CIDs change, after reloading font face
        is @shape.head.code-point, 'A'.ord, 'otf-font glyph "A" cord-point';
        is @shape.head.dx, 575, 'otf-font glyph "A" dx';
        is @shape.tail.code-point, 'b'.ord, 'otf-font glyph "b" cord-point';
        is @shape.tail.dx, 535, 'otf-font glyph "b" dx';

        ok $ttc-font.is-subset, '$ttc-font.is-subset';
        like $ttc-font.font-name, /^<[A..Z]>**6 '+WenQuanYiMicroHei'$/, 'font-name';
        is $ttc-font.encoding, 'Identity-H', '$ttc-font.encoding';
        @shape = $ttc-font.glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:name<A>, :code-point(65), :cid(36), :gid(36), :dx(608), :dy(0)), 'ttc-font glyph "A"';
        is-deeply @shape.tail, Glyph.new(:name<b>, :code-point(98), :cid(69), :gid(69), :dx(586), :dy(0)), 'ttc-font glyph "b"';

        ok $uni-font.is-subset, '$uni-font.is-subset';
        like $uni-font.font-name, /^<[A..Z]>**6 '+DejaVuSans'$/, 'font-name';
        is $uni-font.enc, 'utf16', 'uni-font.encoding';
        @shape = $uni-font.glyphs("Ab");
        is-deeply @shape.head, Glyph.new(:name<A>, :code-point(65), :cid(36), :gid(36), :dx(684), :dy(0)), 'ttc-font glyph "A"';
        is-deeply @shape.tail, Glyph.new(:name<b>, :code-point(98), :cid(69), :gid(69), :dx(635), :dy(0)), 'ttc-font glyph "b"';
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
    .say: '';
    .font = $uni-font;
    .say: "uni font { $uni-font.font-name } {$uni-font.enc} subset ABCxyz";
}

check-fonts('created fonts');

# Don't save PDF files. They have randomly varying font-name prefixes
mkdir 'tmp';

$pdf.save-as: "tmp/subset.pdf";

# check our subsets survive serialization;
$pdf .= open: "tmp/subset.pdf";

my %fonts = $pdf.page(1).resources('Font');
$ttf-font = load-font( dict => %fonts<F1> );
$otf-font = load-font( dict => %fonts<F2> );
$ttc-font = load-font( dict => %fonts<F3> );
$uni-font = load-font( dict => %fonts<F4> );

check-fonts('re-read fonts');

done-testing;
