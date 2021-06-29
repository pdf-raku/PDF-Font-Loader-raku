use Test;
plan 6;
use PDF::Font::Loader :load-font;
use PDF::Font::Loader::Glyph;
use PDF::Lite;
my constant Glyph = PDF::Font::Loader::Glyph;
my PDF::Content::FontObj $deja = load-font( :file<t/fonts/DejaVuSans.ttf>, :!subset );


my PDF::Font::Loader::Glyph @shape = $deja.glyphs("Hello");

is +@shape, 5;

is-deeply @shape.head, Glyph.new: :code-point(72), :cid(43), :gid(43), :dx(752), :dy(0);

is-deeply @shape.tail, Glyph.new: :code-point(111), :cid(82), :gid(82), :dx(612), :dy(0);

# Try shaping a font that lacks a unicode map

my PDF::Lite $pdf .= open: 't/pdf/type1-subset.pdf';
my PDF::Content::Font:D $dict = $pdf.page(1).gfx.resources('Font')<F1>;

my PDF::Font::Loader::FontObj:D $font .= load-font: :$dict;
my uint8 @encoded = 3,5,10;

@shape = $font.glyphs(@encoded);
is-deeply @shape[0], Glyph.new: :code-point(0), :cid(3), :gid(16), :dx(391), :dy(0);
is-deeply @shape[1], Glyph.new: :code-point(0), :cid(5), :gid(25), :dx(558), :dy(0);
is-deeply @shape[2], Glyph.new: :code-point(0), :cid(10), :gid(12), :dx(606), :dy(0);

done-testing;