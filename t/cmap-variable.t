use v6;
use Test;

use PDF::Lite;
use PDF::Font::Loader :&load-font;
use PDF::Font::Loader::Enc::CMap;
use PDF::Font::Loader::Glyph;
use Font::FreeType;
use PDF::Content::Font;
use PDF::Content::FontObj;

my constant Glyph = PDF::Font::Loader::Glyph;

my PDF::Lite $pdf .= open: "t/pdf/cmap-variable.pdf";
my PDF::Content::Font $dict = $pdf.page(1).resources('Font')<F2>;

my PDF::Content::FontObj $font = load-font(:$dict);
my PDF::Font::Loader::Enc::CMap $encoder = $font.encoder;

ok $encoder.is-wide;

is-deeply $encoder.glyph(1), Glyph.new(:name<space>, :code-point(32), :cid(1), :gid(2), :dx(430), :dy(0));
is-deeply $encoder.glyph(2), Glyph.new(:name<exclam>, :code-point(33), :cid(2), :gid(3), :dx(344), :dy(0));
is-deeply $encoder.glyph(0x42), Glyph.new(:name<a>, :code-point(97), :cid(66), :gid(67), :dx(516), :dy(0));

todo "#8 variable CMaps", 3;
is $encoder.decode("\x61\x62\x63"), 'abc', "decode";
is $encoder.decode("\x41\x42\x43"), 'ABC', "decode";
is $encoder.decode("\x31\x32\x33"), '123', "decode";

##is-deeply $encoder.decode("\x61\x62", :cids), array[uint16].new(0x61, 0x62), 'decode-cids';
##is-deeply $encoder.decode("\x41\x42", :cids), array[uint16].new(0x41, 0x42), 'decode-cids';

##is-deeply $encoder.decode("\x5\xF", :ords), $(0x22, 0x2c), 'decode-ords';
##is $encoder.to-unicode[0x5e], 0x6669, 'ligature mapping';
##is-deeply $encoder.decode("\x5e", :ords), $(0x6669, ), "decode ligature";
##$encoder.differences = [0x42, 'C'];
##is $encoder.decode("\x24\x25\x42"), 'ABC', "decode differences";
##is-deeply $encoder.decode("\xA9"), '', "decode unknown";
##my Str $dec = "AB©C\c[DROMEDARY CAMEL]\c[BACTRIAN CAMEL]";
##my Str $enc = "\x24\x25\xA9\x42\x1\x2";
##is-deeply $encoder.encode($dec), $enc, "adaptive encoding";
##is-deeply $encoder.decode($enc), $dec, "adaptive decoding";
done-testing;
