use v6;
use Font::PDF;
use Test;

use Font::PDF::Type1::Stream;

my Blob $buf = "t/fonts/TimesNewRomPS.pfb".IO.open(:r, :bin).slurp;

my Font::PDF::Type1::Stream $stream;
lives-ok { $stream .= new: :$buf}, 'PFB unpacking';
note $stream.length.perl;
is $stream.length[0], 5458, 'stream.length[0]';
is $stream.length[1], 35660, 'stream.length[1]';
is $stream.length[2], 532, 'stream.length[2]';
is $stream.decoded.bytes, $stream.length.sum, 'stream bytes';

my Font::PDF::Type1::Stream $stream2;
$buf = "t/fonts/TimesNewRomPS.pfa".IO.open(:r, :bin).slurp;
lives-ok { $stream2 .= new: :$buf}, 'PFA unpacking';
note $stream.length.perl;
is $stream2.length[0], 5458, 'stream.length[0]';
is $stream2.length[1], 35660, 'stream.length[1]';
is $stream2.length[2], 532, 'stream.length[2]';
is $stream2.decoded.bytes, $stream.length.sum, 'stream bytes';

done-testing;

