use v6;
use Test;

use PDF::IO::IndObj;
use PDF::Grammar::PDF;
use PDF::Grammar::PDF::Actions;
use PDF::Font::Loader::Enc::CMap;
use Font::FreeType;

my PDF::Grammar::PDF::Actions $actions .= new;
my Font::FreeType $freetype .= new;
my $face = $freetype.face('t/fonts/TimesNewRomPS.pfb');

my $input = q:to<--END-->;
593 0 obj <<
  /Length 1816
>> stream
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo
<< /Registry (TTX+0)
/Ordering (T42UV)
/Supplement 0
>> def
/CMapName /TTX+0 def
/CMapType 2 def
1 begincodespacerange <00><FF> endcodespacerange
2 beginbfchar
<05><22>
<5e><6669>
endbfchar
79 beginbfrange
<03><03><20>
<04><04><21>
<09><09><26>
<0a><0a><27>
<0b><0b><28>
<0c><0c><29>
<0e><0e><2b>
<0f><0f><2c>
<10><10><2d>
<11><11><2e>
<12><12><2f>
<13><13><30>
<14><14><31>
<15><15><32>
<16><16><33>
<17><17><34>
<18><18><35>
<19><19><36>
<1a><1a><37>
<1b><1b><38>
<1c><1c><39>
<1d><1d><3a>
<1e><1e><3b>
<24><24><41>
<25><25><42>
<26><26><43>
<27><27><44>
<28><28><45>
<29><29><46>
<2a><2a><47>
<2b><2b><48>
<2c><2c><49>
<2d><2d><4a>
<2e><2e><4b>
<2f><2f><4c>
<30><30><4d>
<31><31><4e>
<32><32><4f>
<33><33><50>
<34><34><51>
<35><35><52>
<36><36><53>
<37><37><54>
<38><38><55>
<39><39><56>
<3a><3a><57>
<3b><3b><58>
<3c><3c><59>
<3d><3d><5a>
<3f><3f><5c>
<41><41><5e>
<42><42><5f>
<44><44><61>
<45><45><62>
<46><46><63>
<47><47><64>
<48><48><65>
<49><49><66>
<4a><4a><67>
<4b><4b><68>
<4c><4c><69>
<4d><4d><6a>
<4e><4e><6b>
<4f><4f><6c>
<50><50><6d>
<51><51><6e>
<52><52><6f>
<53><53><70>
<54><54><71>
<55><55><72>
<56><56><73>
<57><57><74>
<58><58><75>
<59><59><76>
<5a><5a><77>
<5b><5b><78>
<5c><5c><79>
<5d><5d><7a>
endbfrange
endcmap
CMapName currentdict /CMap defineresource pop
end end

endstream
endobj
--END--

PDF::Grammar::PDF.parse($input, :$actions, :rule<ind-obj>)
    // die "parse failed: $input";
my %ast = $/.ast;

my $ind-obj = PDF::IO::IndObj.new( :$input, |%ast );
my $cmap = $ind-obj.object;

my $cmap-obj = PDF::Font::Loader::Enc::CMap.new: :$cmap, :$face;

is-deeply $cmap-obj.decode("\x5\xF"), Buf[uint32].new(0x22, 0x2c), "decode";
is $cmap-obj.decode("\x24\x25\x26", :str), 'ABC', "decode:str";
is-deeply $cmap-obj.decode("\x5e"), Buf[uint32].new(0x6669), "decode ligature";
$cmap-obj.differences = [0x42, 'C'];
is $cmap-obj.decode("\x24\x25\x42", :str), 'ABC', "decode differences";
done-testing;
