use v6;
use Test;
plan 2;

use PDF::IO::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Font::Loader::Enc::CMap :CodeSpace;
use PDF::Font::Loader::Enc::Utf8;
use Font::FreeType;

my PDF::Grammar::PDF::Actions $actions .= new;
my Font::FreeType $freetype .= new;
my $face = $freetype.face('t/fonts/DejaVuSans.ttf');

subtest 'unit-tests', {
    plan 9;
    my PDF::Font::Loader::Enc::Utf8 $encoder .= new: :$face;
    ok $encoder.is-wide;

    my CodeSpace @codespaces = $encoder.codespaces;
    is @codespaces[0].bytes, 1;
    is @codespaces[1].bytes, 2;
    is @codespaces[2].bytes, 3;
    is @codespaces[3].bytes, 4;

    is-deeply $encoder.encode("Hi", :cids), $(43, 76), "cid encoding sanitiy";
    is-deeply $encoder.encode("Hi"), "Hi", "utf-8 encoding sanity";
    is-deeply $encoder.encode("♥", :cids), $(3901, ), "cid multibyte encoding sanitiy";
    is-deeply $encoder.encode("♥").ords, "♥".encode.list, "multibyte encoding sanitiy";
}

subtest 'integration-tests', {
    use PDF::Font::Loader :&load-font;
    use PDF::Font::Loader::FontObj;
    use PDF::Lite;
    my PDF::Lite $pdf .= new;
    my PDF::Font::Loader::FontObj $font = load-font(:enc<utf8>, :file<t/fonts/DejaVuSans.ttf>);
    isa-ok $font.encoder,  PDF::Font::Loader::Enc::Utf8, 'loaded utf8 encoder';
    $pdf.add-page.text: {
        .font = $font, 12;
        .text-position = 10, 500;
        .say: "H";
        .say: "i";
        .say: "♥";
    }
    $pdf.save-as: "t/cmap-utf8.pdf";
}


done-testing;
