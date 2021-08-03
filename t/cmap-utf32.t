use v6;
use Test;
plan 3;

use PDF::IO::IndObj;
use PDF::Font::Loader :&load-font;
use PDF::Font::Loader::FontObj;
use PDF::Font::Loader::Enc::CMap :CodeSpace;
use PDF::Font::Loader::Enc::Unicode;
use PDF::Font::Loader::Glyph;
use Font::FreeType;
use PDF::Lite;

my constant Glyph = PDF::Font::Loader::Glyph;

my Font::FreeType $freetype .= new;
my $face = $freetype.face('t/fonts/DejaVuSans.ttf');

sub utf32-checks($encoder) {
    plan 11;
    isa-ok $encoder, PDF::Font::Loader::Enc::Unicode;
    ok $encoder.is-wide;

    my CodeSpace @codespaces = $encoder.codespaces.List;
    is @codespaces[0].bytes, 4;

    enum ( :H-cid(43), :i-cid(76), :heart-cid(3901) );

    is-deeply $encoder.encode("Hi", :cids), $(+H-cid, +i-cid), "cid encoding sanity";
    is-deeply $encoder.encode("Hi"), flat(0.chr xx 3, 'H', 0.chr xx 3, 'i').join, "utf32 encoding sanity";
    is-deeply $encoder.encode("♥", :cids), $(+heart-cid, ), "cid multibyte encoding sanity";
    is-deeply $encoder.encode("♥").ords, (0, 0, "♥".ord div 256, "♥".ord mod 256), "multibyte encoding sanity";
    is $encoder.decode($encoder.encode("Hi♥")), "Hi♥", "encode/decode round-trip";
    is-deeply $encoder.glyph(+H-cid), Glyph.new(:name<H>, :code-point("H".ord), :cid(+H-cid), :gid(+H-cid), :ax(752)), 'utf32 glyph "H"';
    is-deeply $encoder.glyph(+i-cid), Glyph.new(:name<i>, :code-point("i".ord), :cid(+i-cid), :gid(+i-cid), :ax(278)), 'utf32 glyph "i"';
    is-deeply $encoder.glyph(+heart-cid), Glyph.new(:name<heart>, :code-point("♥".ord), :cid(+heart-cid), :gid(+heart-cid), :ax(896)), 'utf32 glyph "♥"';
}

my PDF::Font::Loader::Enc::Unicode $encoder .= new: :$face, :enc<utf32>;
subtest 'unit-tests', { utf32-checks($encoder) }

skip-rest "Writing of PDFs with UTF32 encoded text is NYI";
exit 0;

subtest 'integration-tests', {
    use PDF::Font::Loader::FontObj;
    my PDF::Lite $pdf .= new;
    my PDF::Font::Loader::FontObj $font = load-font(:enc<utf32>, :file<t/fonts/DejaVuSans.ttf>);
    isa-ok $font.encoder,  PDF::Font::Loader::Enc::Unicode, 'loaded utf32 encoder';
    is $font.encoder.enc, 'utf32';
    $pdf.add-page.text: {
        .font = $font, 12;
        .text-position = 10, 500;
        .say: "Hi♥";
    }
    $pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
    $pdf.save-as: "t/cmap-utf32.pdf";
}

subtest 'reload-dict-tests', {
    my PDF::Lite $pdf .= open:  "t/cmap-utf32.pdf";
    my $dict = $pdf.page(1).resources('Font')<F1>;
    my PDF::Font::Loader::FontObj $font = load-font(:$dict);
    utf32-checks($font.encoder);
}

done-testing;
