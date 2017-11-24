use v6;
use Font::PDF;
use Test;

use Font::PDF::Postscript::Stream;

my Blob $buf = "t/fonts/TimesNewRomPS.pfb".IO.open(:r, :bin).slurp;

my Font::PDF::Postscript::Stream $stream;
lives-ok { $stream .= new: :$buf}, 'PFB unpacking';
note $stream.length.perl;
is $stream.length[0], 5458, 'stream.length[0]';
is $stream.length[1], 35660, 'stream.length[1]';
is $stream.length[2], 532, 'stream.length[2]';
is $stream.decoded.bytes, $stream.length.sum, 'stream bytes';

done-testing;

