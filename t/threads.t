use v6;
use Test;
plan 2;

use PDF::Lite;
use PDF::Font::Loader :&load-font;

my PDF::Content::Page @pages;
my PDF::Lite $pdf .= new;
my $core-font = $pdf.core-font('Courier');

my PDF::Content::FontObj @fonts = <t/fonts/TimesNewRomPS.pfb t/fonts/Vera.ttf t/fonts/Cantarell-Oblique.otf t/fonts/NimbusRoman-Regular.cff>.map: -> $file { load-font :$file }
@fonts.push: $core-font;

lives-ok {
    @pages = (1..20).hyper(:batch(1)).map: -> $page-num {
        my PDF::Content::Page:D $page = PDF::Content::PageTree.page-fragment;
        $page.text: {
            .font = $core-font;
            .say: "Page $page-num", :position[50, 700]; # using a core font
            my $y = 650;
            @fonts.map: -> $font {
                .font = $font, 12;
                .say: '';
                .print: q:to"TEXT", :width(300), :position[50, $y];
                Lorem ipsum dolor sit amet, consectetur adipiscing elit,
                sed do eiusmod tempor incididunt ut labore et dolore
                TEXT
                .font = $font, 10;
                .say: 'magna aliqua.', :position[50, $y - 40];

                $y -= 80;
            }
        }
        $page.finish;
        $page;
    }
}, 'page insert race';

$pdf.add-page($_) for @pages;

# ensure consistant document ID generation
my $basename := "t/threads";
$pdf.id =  "{$basename}.t".fmt('%-16s').substr(0,16);
lives-ok { $pdf.save-as: "{$basename}.pdf"; };

