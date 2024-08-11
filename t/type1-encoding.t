use v6;
use Test;
plan 4;

use PDF::Font::Loader;
use PDF::Lite;
use PDF::Content::FontObj;
my PDF::Lite $pdf .= new;
my PDF::Lite::Page $page = $pdf.add-page;
my @differences = 1, 'b', 'c', 10, 'y', 'z';
my PDF::Content::FontObj $times = PDF::Font::Loader.load-font( :file<t/fonts/TimesNewRomPS.pfb>, :@differences );
is-deeply $times.encode('abcdxyz', :cids).list, (97,1,2,100,120,10,11), 'differences encoding';
$page.text: {
    .text-position = 10,500;
    .font = $times;
    .say: "encoding check: abcdxyz";;
}

# ensure consistant document ID generation
my $basename := "t/type1-encoding";
$pdf.id =  "{$basename}.t".fmt('%-16s').substr(0,16);
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

my Hash $dict = $page.resources('Font').values[0];

lives-ok {
    $times = PDF::Font::Loader.load-font( :$dict );
}, 'reload font from dict - lives';

is-deeply $times.encode('abcdxyz', :cids).list, (97,1,2,100,120,10,11), 'differences re-encoding';

done-testing;

