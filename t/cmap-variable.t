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

# single byte cid range <20> <7E> 1
is $encoder.decode(' ', :cids)[0], 1;
is $encoder.decode('a', :cids)[0], 66;
is $encoder.decode("\x7E", :cids)[0], (0x7E - 0x20 + 1);
is $encoder.encode('abc'), 'abc';

# first multibyte cid range <8140> <817E> 633
is $encoder.decode("\x81\x40", :cids)[0], 633;
is $encoder.decode("\x81\x41", :cids)[0], 634;

done-testing;
