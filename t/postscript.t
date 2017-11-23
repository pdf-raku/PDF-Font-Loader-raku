use v6;
use Font::PDF;
use Test;

use Font::PDF::Postscript::Stream;

my Blob $raw = "t/fonts/TimesNewRomPS.pfb".IO.open(:r, :bin).slurp;

my $unpacked;
lives-ok { $unpacked =Font::PDF::Postscript::Stream.unpack($raw)}, 'PFB unpacking';

done-testing;

