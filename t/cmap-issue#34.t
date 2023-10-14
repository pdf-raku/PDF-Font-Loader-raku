use v6;
use Test;
plan 3;
use PDF::IO::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Font::Loader::Enc::CMap;
use Font::FreeType;

my PDF::Grammar::PDF::Actions $actions .= new;
my Font::FreeType $freetype .= new;
my $face = $freetype.face('t/fonts/TimesNewRomPS.pfb');

my $input = q:to<--END-->;
230 0 obj
<< /Length 1588 >> stream
/CIDInit /ProcSet findresource begin
25 dict begin
begincmap
/CIDSystemInfo
<< /Registry (Adobe)
/Ordering (UCS)
/Supplement 0
>> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
2 beginbfrange
<0003> <0004> [<0020> <0041>]
<0011> <0012> <0042>
endbfrange
9 beginbfchar
<0018> <0044>
<001C> <0045>
<0027> <0047>
<002C> <0048>
<002F> <0049>
<0037> <0130>
<003A> <004A>
<003C> <004B>
<003E> <004C>
endbfchar
1 beginbfrange
<0044> <0045> <004D>
endbfrange
6 beginbfchar
<004B> <004F>
<0050> <00D6>
<0057> <0050>
<005A> <0052>
<005E> <0053>
<0064> <0054>
endbfchar
1 beginbfrange
<0073> <0074> <0056>
endbfrange
1 beginbfchar
<0102> <0061>
endbfchar
1 beginbfrange
<010F> <0110> <0062>
endbfrange
11 beginbfchar
<0111> <0107>
<011A> <0064>
<011E> <0065>
<0128> <0066>
<0150> <0067>
<015A> <0068>
<015D> <0069>
<0166> <0131>
<0169> <006A>
<016C> <006B>
<016F> <006C>
endbfchar
1 beginbfrange
<0175> <0176> <006D>
endbfrange
2 beginbfchar
<017D> <006F>
<0189> <0070>
endbfchar
1 beginbfrange
<018B> <018C> <0071>
endbfrange
3 beginbfchar
<0190> <0073>
<019A> <0074>
<01B5> <0075>
endbfchar
2 beginbfrange
<01C0> <01C1> <0076>
<01C6> <01C7> <0078>
endbfrange
2 beginbfchar
<01CC> <007A>
<034D> <003F>
endbfchar
6 beginbfrange
<0355> <0359> [<002C> <003B> <003A> <002E> <2026>]
<035A> <035B> <2018>
<035E> <035F> <201C>
<037E> <037F> <0028>
<0396> <0398> [<0027> <0022> <0026>]
<03EC> <03EF> <0030>
endbfrange
3 beginbfchar
<03F1> <0035>
<03F5> <0039>
<0439> <0025>
endbfchar
endcmap
CMapName currentdict /CMap defineresource pop
end
end
endstream
endobj
--END--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my %ast = $/.ast;

my PDF::IO::IndObj $ind-obj .= new( :$input, |%ast );
my $cmap = $ind-obj.object;

my PDF::Font::Loader::Enc::CMap $encoder .= new: :$cmap, :$face, :!is-wide;
ok $encoder.is-wide;

my $enc = "\x[3]~\0\x[4]\x[1]\x[F]\x[1]µ\x[1]l\x[1]u\x[1]\x[1E]\x[1]]\x[1]o\x[3]U\0\x[3]\x[1]\x[1E]\x[1]\x[9A]\0\x[3]\x[1]\x[2]\x[1]o\x[3]X\x[3]U\0\x[3]\x[3]î\x[3]ì\x[3]î\x[3]í\x[3]V";
my $dec = '(Abukmeil, et al., 2021;';

is $encoder.decode($enc, :str), $dec;
is $encoder.encode($dec, :str), $enc;


