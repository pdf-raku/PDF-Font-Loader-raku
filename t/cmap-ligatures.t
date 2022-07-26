use Test;
plan 2;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Font::Loader::FontObj;

my PDF::Lite $pdf .= open: "t/pdf/cmap-ligatures.pdf";

my $dict = $pdf.page(1)<Resources><Font><C2_0>;

my PDF::Font::Loader::FontObj:D $font = PDF::Font::Loader.load-font: :$dict;

my $bytes = buf8.new(0x00,0x32, 0x00,0x49, 0x01,0x93, 0x00,0x46, 0x00,0x48).decode: "latin-1";
is $dict.decode($bytes), 'Ofﬁce';
is-deeply $dict.encode('Ofﬁce'), $bytes;
