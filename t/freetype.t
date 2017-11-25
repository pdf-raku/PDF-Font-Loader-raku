use v6;
use Font::PDF;
use PDF::Lite;
use Test;
# ensure consistant document ID generation
srand(123456);
my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $deja = Font::PDF.load-font("t/fonts/DejaVuSans.ttf");
my $deja-vu = Font::PDF.load-font("t/fonts/DejaVuSans.ttf", :enc<win>);
my $otf-font = Font::PDF.load-font("t/fonts/Cantarell-Oblique.otf");

$page.text: {
   .font = $deja;
   .text-position = [10, 760];
   .say: 'Hello, world';
   .say: 'WAV', :kern;
   my $s;
   my $n = 0;
   .font = $deja, 8;
   $deja.face.forall-chars: -> $_ { $s ~= .char-code.chr;
                             $s ~= ' ' if $n++ %% 78
   };
   .say: $s, :width(400);
}
$page = $pdf.add-page;
$page.text: {
   .text-position = [10, 500];
   .font = $otf-font;
   .say: "Sample Open Type Font";
   .font = $deja-vu;
   .say: 'Bye, for now';
}
lives-ok { $pdf.save-as: "t/freetype.pdf"; };

done-testing;

