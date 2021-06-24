use v6;
use Test;
plan 24;
use PDF::Grammar::Test :is-json-equiv;
use PDF::Font::Loader :Weight, :Stretch, :Slant;
use PDF::Content::FontObj;

ok 'medium' ~~ Weight, 'FontWeight subset';
ok '200' ~~ Weight, 'FontWeight subset';
ok 200 ~~ Weight, 'FontWeight subset';
nok 'average' ~~ Weight, 'FontWeight subset';
nok -3 ~~ Weight, 'FontWeight subset';

my PDF::Content::FontObj $vera = PDF::Font::Loader.load-font: :file<t/fonts/Vera.ttf>, :!subset;
is $vera.font-name, 'BitstreamVeraSans-Roman', 'font-name';

is $vera.height.round, 1164, 'font height';
is $vera.height(:from-baseline).round, 928, 'font height from baseline';
is $vera.height(:hanging).round, 1164, 'font height hanging';
is-approx $vera.height(12), 13.96875, 'font height @ 12pt';
is-approx $vera.height(12, :from-baseline), 11.138672, 'font base-height @ 12pt';
my $times = PDF::Font::Loader.load-font: :file<t/fonts/TimesNewRomPS.pfa>;
# Vera defines: AB˚. Doesn't include: ♥♣✔
is-deeply $times.encode("A♥♣✔˚B", :str), "A\x[1]B", '.encode(...) sanity';

is $vera.stringwidth("RVX", :!kern), 2064, 'stringwidth :!kern';
is $vera.stringwidth("RVX", :kern), 2064 - 55, 'stringwidth :kern';
is-deeply $vera.kern("RVX" ), (['R', -55, 'VX'], 2064 - 55), '.kern(...)';
is-deeply $vera.kern('ABCD' ), (['AB', -18, 'CD'], 2820), '.kern(...)';

is $vera.glyph-width('V'), 684;
$vera.glyph-width('V') -= 20;
is $vera.glyph-width('V'), 664;
is $vera.stringwidth("RVX", :!kern), 2044, 'stringwidth, width adjustment';

my Hash $times-dict = $times.cb-finish();
my $descriptor-dict = $times-dict<FontDescriptor>:delete;
is-json-equiv $times-dict, {
    :Type<Font>,
    :Subtype<Type1>,
    :BaseFont<TimesNewRomanPS>,
    :Encoding{
        :Type("Encoding")
        :BaseEncoding<WinAnsiEncoding>,
        :Differences[1, "ring"],
    },
    :FirstChar(1),
    :LastChar(66),
    :Widths[flat 333,  0 xx 63,  722, 667],
}, "to-dict";

for ($times => "Á®ÆØ",
     $vera => "\0É\0\x[8a]\0\x[90]\0\x[91]") {
    my ($font, $encoded) = .kv;
    my $decoded = "Á®ÆØ";
    my $re-encoded = $font.encode($decoded, :str);
    is-deeply $re-encoded, $encoded, "{$font.face.postscript-name} encoding";
    is-deeply $font.decode($encoded, :str), $decoded, "{$font.face.postscript-name} decoding";
}

done-testing;
