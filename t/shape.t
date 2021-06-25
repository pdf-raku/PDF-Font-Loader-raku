use Test;
plan 3;
use PDF::Font::Loader :load-font;
use PDF::Font::Loader::Metrics;
my constant Metrics = PDF::Font::Loader::Metrics;
my PDF::Content::FontObj $deja = load-font( :file<t/fonts/DejaVuSans.ttf>, :!subset );

my PDF::Font::Loader::Metrics @shape = $deja.shape("Hello");

is +@shape, 5;

is-deeply @shape.head, Metrics.new: :code-point(72), :cid(43), :dx(752e-3), :dy(0e0);

is-deeply @shape.tail, Metrics.new: :code-point(111), :cid(82), :dx(612e-3), :dy(0e0);

done-testing;