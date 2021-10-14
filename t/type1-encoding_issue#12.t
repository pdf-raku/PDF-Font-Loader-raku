use v6;
use Test;
plan 9;

use PDF::IO::IndObj;
use PDF::Font::Loader :&load-font;
use PDF::Font::Loader::FontObj;
use PDF::Font::Loader::Enc::CMap :CodeSpace;
use PDF::Font::Loader::Enc::Unicode;
use PDF::Font::Loader::Glyph;
use Font::FreeType;
use PDF::Lite;

my constant Glyph = PDF::Font::Loader::Glyph;

sub encoding-checks($encoder) {
    isa-ok $encoder, PDF::Font::Loader::Enc::CMap;
    ok $encoder.is-wide;

    my CodeSpace @codespaces = $encoder.codespaces.List;
    is +@codespaces, 1;
    is @codespaces[0].bytes, 2;

    dd $encoder.encode("Hi");
    # identity mappings
    enum ( :H-cid('H'.ord), :i-cid('i'.ord) );
    enum ( :H-gid(32), :i-gid(60) );
    is-deeply $encoder.encode("Hi", :cids), $(+H-cid, +i-cid), "cid encoding sanity";
    is-deeply $encoder.encode("Hi"), 'Hi', "str encoding sanity";
    note $encoder.decode("Hi", :cids);
    is-deeply $encoder.encode("Hi"), "Hi", "win encoding sanity";
    is-deeply $encoder.glyph(+H-cid), Glyph.new(:name<H>, :code-point("H".ord), :cid(+H-cid), :gid(+H-gid), :ax(652)), 'glyph "H"';
    is-deeply $encoder.glyph(+i-cid), Glyph.new(:name<i>, :code-point("i".ord), :cid(+i-cid), :gid(+i-gid), :ax(234)), 'glyph "i"';
}

my PDF::Lite $pdf .= open:  "t/pdf/type1-encoding_issue#12.pdf";
my $dict = $pdf.page(1).resources('Font')<T1_0>;
my PDF::Font::Loader::FontObj $font = load-font(:$dict);
encoding-checks($font.encoder);

done-testing;
