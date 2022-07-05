use v6;
use Test;
plan 2;
use PDF::Lite;
use PDF::Content;
use PDF::Content::FontObj;
use PDF::Font::Loader;

my PDF::Lite $pdf .= new();
my PDF::Lite::Page $page = $pdf.add-page;
my PDF::Content $gfx = $page.gfx;
my $width = 100;
my $height = 80;
my $x = 110;

my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :file<t/fonts/Vera.ttf>, :!subset, :prefix<ABCDEF>;

is-deeply $font.encode("Abc€√b").ords, (0,36, 0,69, 0,70, 1,2, 0,165, 0,69), 'encode (identity-h)';

$gfx.text: -> $gfx {
    $gfx.font = $font, 10;

    my $sample = q:to"--ENOUGH!!--";
        Lorem ipsum dolor sit amet, consectetur adipiscing elit,  sed
        do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        --ENOUGH!!--

    my $baseline = 'top';

    for <top center bottom> -> $valign {

        my $y = 700;

        for <left center right justify> -> $align {
            $gfx.text-position = ($x, $y);
            $gfx.say( "*** $valign $align*** " ~ $sample, :$width, :$height, :$valign, :$align, :$baseline );
            $y -= 170;
        }

       $x += 125;
    }
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16.16s');

lives-ok {$pdf.save-as('t/pdf-text-align.pdf')};

done-testing;
