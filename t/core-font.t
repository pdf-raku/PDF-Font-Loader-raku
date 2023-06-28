use v6;
use PDF::Font::Loader;
use PDF::Lite;
use PDF::Content::FontObj;
use Test;
my PDF::Lite $pdf .= new;
my $page = $pdf.add-page;
my PDF::Content::FontObj $times = PDF::Font::Loader.load-font: :family<times>, :core-font;
my $zapf = PDF::Font::Loader.load-font: :family<ZapfDingbats>, :core-font;

isa-ok $times, 'PDF::Content::Font::CoreFont';
isa-ok $zapf, 'PDF::Content::Font::CoreFont';

$page.text: {
   .font = $times;
   .text-position = [10, 700];
   .say: 'Hello, world';
   .font = $zapf;
   .say: "★☎☛☞♠♣♥";
   for $times, $zapf -> $font {
       my $s;
       my $n = 0;
       .font = $font;
       for $font.encoder.to-unicode -> UInt $ord {
           $s ~= $ord.chr;
           $s ~= ' ' if $n++ %% 10
        };
       .say: $s, :width(400);
       .say: '';
   }
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16s').substr(0,16);

lives-ok { $pdf.save-as: "t/core-font.pdf"; };

$pdf .= open: "t/core-font.pdf";

my Hash $dict = $pdf.page(1)<Resources><Font><F1>;
my $f = PDF::Font::Loader.load-font: :$dict, :quiet;
nok $f.isa('PDF::Content::Font::CoreFont');

$f = PDF::Font::Loader.load-font: :$dict, :core-font;
ok $f.isa('PDF::Content::Font::CoreFont');

done-testing;

