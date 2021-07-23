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
is $encoder.codespaces[0].Str, '<00> <80>'; 
is $encoder.codespaces[0].bytes, 1; 
ok  0x20 ~~ $encoder.codespaces[0];
ok  0x80 ~~ $encoder.codespaces[0];
nok 0x81 ~~ $encoder.codespaces[0];
nok 0x20 ~~ $encoder.codespaces[1];
is $encoder.enc-width(0x20), 1;
is $encoder.enc-width(0x7E), 1;

# single byte cid range <00> <80>
is $encoder.decode(' ', :cids)[0], 1;
is $encoder.decode('a', :cids)[0], 66;
is $encoder.decode("\x7E", :cids)[0], (0x7E - 0x20 + 1);
is $encoder.encode('abc'), 'abc';

# first multibyte cid range <8140> <9FFC>
nok 0x8140 ~~ $encoder.codespaces[0];
is  $encoder.codespaces[1].Str, '<8140> <9FFC>'; 
is  $encoder.codespaces[1].bytes, 2; 
ok  0x8140 ~~ $encoder.codespaces[1];
ok  0x9FFC ~~ $encoder.codespaces[1];
nok 0x9FFD ~~ $encoder.codespaces[1];
nok 0x8230 ~~ $encoder.codespaces[1];

is $encoder.enc-width(0x8140), 2;
is $encoder.enc-width(0x817E), 2;
is $encoder.decode("\x81\x40", :cids)[0], 633;
is $encoder.decode("\x81\x41", :cids)[0], 634;

done-testing;
