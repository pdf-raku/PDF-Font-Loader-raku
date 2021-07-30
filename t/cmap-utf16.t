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

sub utf16-checks($encoder) {
    plan 15;
    isa-ok $encoder, PDF::Font::Loader::Enc::Unicode;
    ok $encoder.is-wide;

    my CodeSpace @codespaces = $encoder.codespaces.List;
    is @codespaces[0].bytes, 2;
    is @codespaces[1].bytes, 4;
    is @codespaces[2].bytes, 2;

    enum ( :H-cid(43), :i-cid(76), :heart-cid(3901) );

    is $encoder.encoded-width('H'.ord), 2;
    is $encoder.encoded-width('♥'.ord), 2;

    is-deeply $encoder.encode("Hi", :cids), $(+H-cid, +i-cid), "cid encoding sanity";
    is-deeply $encoder.encode("Hi"), (0.chr, 'H', 0.chr, 'i').join, "utf16 encoding sanity";
    is-deeply $encoder.encode("♥", :cids), $(+heart-cid, ), "cid multibyte encoding sanity";
    is-deeply $encoder.encode("♥").ords, ("♥".ord div 256, "♥".ord mod 256), "multibyte encoding sanity";
    is $encoder.decode($encoder.encode("Hi♥")), "Hi♥", "encode/decode round-trip";
    is-deeply $encoder.glyph(+H-cid), Glyph.new(:name<H>, :code-point("H".ord), :cid(+H-cid), :gid(+H-cid), :dx(752), :dy(0)), 'utf16 glyph "H"';
    is-deeply $encoder.glyph(+i-cid), Glyph.new(:name<i>, :code-point("i".ord), :cid(+i-cid), :gid(+i-cid), :dx(278), :dy(0)), 'utf16 glyph "i"';
    is-deeply $encoder.glyph(+heart-cid), Glyph.new(:name<heart>, :code-point("♥".ord), :cid(+heart-cid), :gid(+heart-cid), :dx(896), :dy(0)), 'utf16 glyph "♥"';
}

my PDF::Font::Loader::Enc::Unicode $encoder .= new: :$face, :enc<utf16>;
subtest 'unit-tests', { utf16-checks($encoder) }

subtest 'integration-tests', {
    use PDF::Font::Loader::FontObj;
    my PDF::Lite $pdf .= new;
    my PDF::Font::Loader::FontObj $font = load-font(:enc<utf16>, :file<t/fonts/DejaVuSans.ttf>);
    isa-ok $font.encoder,  PDF::Font::Loader::Enc::Unicode, 'loaded utf16 encoder';
    is $font.encoder.enc, 'utf16';
    $pdf.add-page.text: {
        .font = $font, 12;
        .text-position = 10, 500;
        .say: "Hi♥";
    }
    $pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
    $pdf.save-as: "t/cmap-utf16.pdf";
}

subtest 'reload-dict-tests', {
    my PDF::Lite $pdf .= open:  "t/cmap-utf16.pdf";
    my $dict = $pdf.page(1).resources('Font')<F1>;
    my PDF::Font::Loader::FontObj $font = load-font(:$dict);
    utf16-checks($font.encoder);
}

done-testing;
