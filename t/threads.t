use v6;
use Test;
plan 2;

use PDF::Lite;
use PDF::Font::Loader :&load-font;

my PDF::Lite $pdf .= new;
my PDF::Content::Page @pages;

my PDF::Content::FontObj @fonts = <t/fonts/TimesNewRomPS.pfb t/fonts/DejaVuSans.ttf t/fonts/Cantarell-Oblique.otf t/fonts/NimbusRoman-Regular.cff>.map: -> $file { load-font :$file }

lives-ok {
    @pages = (1..20).race(:batch(1)).map: -> $page-num {
        my PDF::Content::Page:D $page = PDF::Content::PageTree.page-fragment;
        $page.graphics: {
            .say: "Page $page-num", :position[50, 700]; # using a core font
            my $y = 650;
            @fonts.map: -> $font {
                .font = $font;
                .say: '';
                .say: q:to"TEXT", :width(300), :position[50, $y];
                Lorem ipsum dolor sit amet, consectetur adipiscing elit,
                sed do eiusmod tempor incididunt ut labore et dolore
                magna aliqua.
                TEXT
                $y -= 80;
            }
        }
        $page;
    }
}, 'page insert race';

$pdf.add-page($_) for @pages;

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');

lives-ok { $pdf.save-as('t/threads.pdf'); }, 'save-as';

