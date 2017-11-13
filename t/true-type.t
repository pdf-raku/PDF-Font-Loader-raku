use v6;
use PDF::Font;
use PDF::Lite;
use Test;

# ensure consistant document ID generation
srand(123456);
my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $deja = PDF::Font.load-font("t/fonts/DejaVuSans.ttf");
my $deja-vu = PDF::Font.load-font("t/fonts/DejaVuSans.ttf", :enc<win>);
my $otf-font = PDF::Font.load-font("t/fonts/Cantarell-Oblique.otf");

$page.text: {
   .font = $deja;
   .text-position = [10, 50];
   .say: 'Hello, world';
   .say: 'RVX', :kern;
}
$page = $pdf.add-page;
$page.text: {
   .text-position = [10, 50];
   .font = $otf-font;
   .say: "Sample Open Type Font";
   .font = $deja-vu;
   .say: 'Bye, for now';
}
lives-ok { $pdf.save-as: "t/true-type.pdf"; };

done-testing;

