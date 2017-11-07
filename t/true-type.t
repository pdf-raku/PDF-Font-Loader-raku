use v6;
use PDF::Font;
use PDF::Lite;
use Test;

# ensure consistant document ID generation
srand(123456);
my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;

$page.text: {
   .font = .use-font: PDF::Font.load-font("t/fonts/DejaVuSans.ttf");
   .text-position = [10, 10];
   .say: 'Hello, world';
}
$pdf.save-as: "t/true-type.pdf";
