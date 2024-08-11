use Test;
plan 13;
use PDF::Font::Loader :load-font;
use PDF::Font::Loader::FontObj;
use PDF::Font::Loader::Glyph;
use PDF::Lite;
use PDF::Content;
use PDF::Content::Font;
use Font::FreeType;
my constant Glyph = PDF::Font::Loader::Glyph;
my PDF::Content::FontObj $vera = load-font( :file<t/fonts/Vera.ttf>, :!subset );

my Glyph @shape = $vera.get-glyphs("Hello");

is +@shape, 5;

is-deeply @shape.head, Glyph.new(:name<H> :code-point(72), :cid(43), :gid(43), :ax(752), :sx(752));

is-deeply @shape.tail, Glyph.new(:name<o>, :code-point(111), :cid(82), :gid(82), :ax(612), :sx(612));

# Try shaping a font that lacks a unicode map

my PDF::Lite $pdf .= open: 't/pdf/type1-subset.pdf';
my $gfx =  $pdf.page(1).gfx;
my PDF::Content::Font:D $dict = $gfx.resources('Font')<F1>;

my PDF::Font::Loader::FontObj:D $font .= load-font: :$dict;
my uint8 @encoded = 3,5,10;

@shape = $font.get-glyphs(@encoded);
is-deeply @shape[0], Glyph.new: :name<g85>, :code-point(0), :cid(3), :gid(16), :ax(391), :sx(391);
is-deeply @shape[1], Glyph.new: :name<g74>, :code-point(0), :cid(5), :gid(25), :ax(558), :sx(558);
is-deeply @shape[2], Glyph.new: :name<g69>, :code-point(0), :cid(10), :gid(12), :ax(606), :sx(606);

# See if we can setup an encoding that survives serialization
my $face = $font.face;
my $encoder = $font.encoder;
my $cid = 0;
my %glyphs;

for $encoder.differences.list {
    when Int { $cid = $_ }
    when Str {
         %glyphs{$_} = $cid++
    }
}

for '–' => 'g179', :O<g50>, :r<g85>, :i<g76>, :g<g74>, :n<g81>,
:a<g68>, :l<g79>, :A<g36>, :b<g69>, :s<g86>, :t<g87>, :c<g70>,
'.' => 'g17', ' ' => 'g3', :K<g46>, :e<g72>, y => 'g92', :w<g90>,
:o<g82>, :d<g71>, ':' => 'g29', :J<g45>, :R<g53>, :p<g83>, :D<g39>,
:v<g89>, '4' => 'g23', '7' => 'g26', :M<g48>, :h<g75>, :u<g88>, :T<g55>,
'1' => 'g20', '2' => 'g21', :F<g41>, '3' => 'g22', :k<g78>, :m<g80>,
:f<g73>, :Z<g61>, :U<g56>, ',' => 'g15', :V<g57>, :W<g58>, :S<g54>,
:C<g38>, :H<g43>, :I<g44>, :E<g40>, :Y<g60>, :B<g37>, :G<g42>, :P<g51>,
:L<g47>, :N<g49>, :z<g93>, :X<g59>, :j<g77>, '-' => 'g16', :Q<g52> {
    $encoder.set-encoding(.key.ord,%glyphs{.value});
}

# We should now be able to do unicode encoding
@shape = $font.get-glyphs("HiQ");
is-deeply @shape[0], Glyph.new(:name<H>, :code-point(72),  :cid(48), :gid(26), :ax(823), :sx(823)), 'pre-save encoding';
is-deeply @shape[1], Glyph.new(:name<i>, :code-point(105), :cid(4),  :gid(21), :ax(334), :sx(334)), 'pre-save encoding';
is-deeply @shape[2], Glyph.new(:name<Q>, :code-point(81),  :cid(61), :gid(6),  :ax(823), :sx(823)), 'pre-save encoding';

## reserialize. check than encodings are intact

my $basename := "t/type1-add-encoding";
my $ID = "{$basename}.t".fmt('%-16s').substr(0,16);
$pdf.id = $ID;
$pdf .= open: $pdf.Blob;
$dict = $pdf.page(1).resources('Font')<F1>;
$font .= load-font: :$dict;

@shape = $font.get-glyphs("HiQ");
is-deeply @shape[0], Glyph.new(:name<H>, :code-point(72),  :cid(48), :gid(26), :ax(823), :sx(823)), 'reloaded encoding';
is-deeply @shape[1], Glyph.new(:name<i>, :code-point(105), :cid(4),  :gid(21), :ax(334), :sx(334)), 'reloaded encoding';
is-deeply @shape[2], Glyph.new(:name<Q>, :code-point(81),  :cid(61), :gid(6),  :ax(823), :sx(823)), 'reloaded encoding';

$pdf.page(1).gfx.text: {
    .font = $font;
    .text-position = 50, 500;
    .say: "Added string";
}

$pdf.id = $ID;
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

done-testing;
