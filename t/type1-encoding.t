use v6;
use PDF::Font::Loader;
use PDF::Lite;
use Test;
# ensure consistant document ID generation
srand(123456);
my PDF::Lite $pdf .= new;
my PDF::Lite::Page $page = $pdf.add-page;
my @differences = 1, 'b', 'c', 10, 'y', 'z';
my $times = PDF::Font::Loader.load-font( :file<t/fonts/TimesNewRomPS.pfb>, :@differences );
is-deeply $times.encode('abcdxyz'), buf8.new(97,1,2,100,120,10,11), 'differences encoding';
$page.text: {
    .text-position = 10,500;
    .font = $times;
    .say: "encoding check: abcdxyz";;
}
lives-ok { $pdf.save-as: "t/type1-encoding.pdf"; };

my Hash $dict = $page.resources('Font').values[0];

##lives-ok {
$times = PDF::Font::Loader.load-font( :$dict ); ## }, 'reload font from dict - lives';

is-deeply $times.encode('abcdxyz'), buf8.new(97,1,2,100,120,10,11), 'differences re-encoding';

done-testing;

