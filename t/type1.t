use v6;
use Font::PDF;
use PDF::Lite;
use Test;
# ensure consistant document ID generation
srand(123456);
my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $times = Font::PDF.load-font("t/fonts/TimesNewRomPS.pfb");

$page.text: {
   .font = $times;
   .text-position = [10, 500];
   .say: 'Hello, world';
   my $s;
   my $n = 0;
   $times.face.forall-chars: -> $_ { $s ~= .char-code.chr;
                             $s ~= ' ' if $n++ %% 64
   };
   .say: $s, :width(400);
}
lives-ok { $pdf.save-as: "t/type1.pdf"; };

done-testing;

