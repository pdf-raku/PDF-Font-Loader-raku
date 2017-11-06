use v6;
use PDF::Font::FreeType;
use PDF::Lite;
use Test;

# ensure consistant document ID generation
srand(123456);
my $font;
lives-ok {$font = PDF::Font::FreeType.load-font("t/fonts/DejaVuSans.ttf");};

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $font-resource = $page.use-font($font);

$page.text: {
    .set-font($font-resource);
    .TextMove(10, 20);
    .ShowText("Hello TrueType World");
}
$pdf.save-as: "t/true-type.pdf";
