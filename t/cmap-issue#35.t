use v6;
use Test;
plan 4;
use PDF::IO::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Font::Loader::Enc::CMap;
use Font::FreeType;

my PDF::Grammar::PDF::Actions $actions .= new;
my Font::FreeType $freetype .= new;
my $face = $freetype.face('t/fonts/TimesNewRomPS.pfb');

my $input = q:to<--END-->;
3208 0 obj
<< /Length 609 >> stream
/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CIDSystemInfo <<
/Registry (AAAAAA+F22+0) /Ordering (T1UV) /Supplement 0 >> def
/CMapName /AAAAAA+F22+0 def
/CMapType 2 def
1 begincodespacerange <02> <90> endcodespacerange
3 beginbfchar
<20> <0020>
<3b> <003B>
<90> <2019>
endbfchar
9 beginbfrange
<28> <29> <0028>
<2c> <36> <002C>
<38> <39> <0038>
<41> <50> <0041>
<52> <54> <0052>
<56> <57> <0056>
<59> <5a> <0059>
<61> <7a> <0061>
<8d> <8e> <201C>
endbfrange
2 beginbfrange
<02> <02> [<00540068>]
<03> <03> [<00660069>]
endbfrange
endcmap CMapName currentdict /CMap defineresource pop end end

endstream
endobj
--END--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my %ast = $/.ast;

my PDF::IO::IndObj $ind-obj .= new( :$input, |%ast );
my $cmap = $ind-obj.object;

my PDF::Font::Loader::Enc::CMap $encoder .= new: :$cmap, :$face, :!is-wide;
nok $encoder.is-wide;

my $enc = " ;\x[90](,8ARVYa\x[8D]\x[2]\x[3]";
my $enc2 = " ;\x[90](,8ARVYa\x[8D]Th\x[3]";
my $dec = ' ;’(,8ARVYa“Thﬁ';

is $encoder.decode($enc, :str), $dec, 'decode';
# 'Th' is custom ligature that does have a Unicode mapping
is $encoder.encode($dec, :str), $enc2, 'encode';
is $encoder.decode($enc, :str), $dec, 'decode';


