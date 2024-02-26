use v6;
use Test;
plan 2;
use PDF::Lite;
use PDF::Content;
use PDF::Content::Color :&color;
use PDF::Content::FontObj;
use PDF::Font::Loader;

sub draw-rect($gfx, @rect) {
    $gfx.tag: 'Artifact', {
        $gfx.StrokeAlpha = .5;
        $gfx.StrokeColor = color .5, .01, .01;
        $gfx.paint: :stroke, { .Rectangle(@rect[0], @rect[1], @rect[2] - @rect[0], @rect[3] - @rect[1]); }
    }
}

sub draw-cross($gfx, $x, $y) {
    $gfx.tag: 'Artifact', {
        $gfx.StrokeAlpha = .75;
        $gfx.StrokeColor = color .01, .7, 0.1;
        $gfx.paint: :stroke, { .MoveTo($x-5, $y);  .LineTo($x+5, $y); }
        $gfx.paint: :stroke, { .MoveTo($x, $y-5);  .LineTo($x, $y+5); }
    }
}

my PDF::Lite $pdf .= new();
my PDF::Lite::Page $page = $pdf.add-page;
my PDF::Content $gfx = $page.gfx;
my $width = 120;
my $x = 125;

my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :file<t/fonts/Vera.ttf>, :!subset, :prefix<ABCDEF>;

is-deeply $font.encode("Abc€√b").ords, (0,36, 0,69, 0,70, 1,2, 0,165, 0,69), 'encode (identity-h)';
$gfx.Save;
$gfx.font = $font, 10;

my $sample = q:to"--ENOUGH!!--";
Lorem ipsum dolor sit amet, consectetur adipiscing elit,  sed
do eiusmod tempor incididunt ut labore et dolore magna aliqua.
--ENOUGH!!--

for <top center bottom> -> $valign {

    my $y = 700;

    for <left center right justify> -> $align {
        my @rect[4];
        $gfx.&draw-cross($x, $y);
        $gfx.text: {
            .text-position = ($x, $y);
            @rect = .print( "*** $valign $align*** " ~ $sample, :$width, :$valign, :$align, );
        }
        draw-rect $gfx, @rect;
        $y -= 170;
    }

    $x += 125;
}

$gfx.Restore;
# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16.16s');

lives-ok {$pdf.save-as('t/pdf-text-align.pdf')};

done-testing;
