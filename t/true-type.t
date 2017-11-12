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

$page.text: {
   .font = $deja;
   .text-position = [10, 10];
   .say: 'Hello, world';
}
$page = $pdf.add-page;
$page.text: {
   .font = $deja-vu;
   .text-position = [10, 10];
   .say: 'Bye, for now';
}
lives-ok { $pdf.save-as: "t/true-type.pdf"; };

done-testing;

