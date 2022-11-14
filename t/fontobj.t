use v6;
use PDF::Font::Loader :&load-font;
use PDF::Content::FontObj;
use PDF::Lite;
use Test;

my PDF::Lite $pdf .= new;
my PDF::Content::FontObj $vera     = load-font :file<t/fonts/Vera.ttf>, :!subset;
my PDF::Content::FontObj $otf-font = load-font :file<t/fonts/Cantarell-Oblique.otf>, :enc<win>;
my PDF::Content::FontObj $cff-font = load-font :file<t/fonts/NimbusRoman-Regular.cff>, :enc<win>;
my PDF::Content::FontObj $cid-keyed-font = load-font :file<t/fonts/NotoSansHK-Regular-subset.otf>, :!subset;
# True collections don't embed without subsetting
my PDF::Content::FontObj $ttc-font = load-font :file<t/fonts/Sitka.ttc>, :!embed, :!subset;

is $vera.underline-position, -284;
is $vera.underline-thickness, 143;

my $n = 0;
my $vera-chars;

$vera.face.forall-chars: :!load,  {
    $vera-chars ~= .char-code.chr;
    $vera-chars ~= ' ' if ++$n %% 64;
};

$pdf.add-page.text: {
   .font = $vera;
   .text-position = [10, 760];
   .say: 'Hello, world';
   .say: 'WAV', :kern;
   .font = $vera, 12;

   .say: $vera-chars, :width(300);
}

$pdf.add-page.text: {
   .text-position = [10, 700];
   .font = $otf-font;
   .say: "Sample Open Type Font: {$otf-font.font-name}";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';

   .text-position = [10, 650];
   .font = $cff-font;
   .say: "Sample CFF Font: {$cff-font.font-name}";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';

   .text-position = [10, 600];
   .font = $ttc-font;
   .say: "Sample TTC (TrueType collection) Font - not embedded";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';

   .text-position = [10, 550];
   .font = $cid-keyed-font;
   .say: "sample cid keyed font embedded";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';

   .text-position = [10, 500];
   .font = .core-font: 'Times';
   .say: "Core Font (Times)";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';
}

multi sub font-type(PDF::Font::Loader::FontObj::CID:D $font) {
    $font.to-dict<DescendantFonts>[0]<Subtype>;
}

multi sub font-type(PDF::Font::Loader::FontObj:D $font) {
    $font.to-dict<Subtype>;
}

is font-type($vera), 'CIDFontType2';
is font-type($otf-font), 'Type1';
is font-type($cff-font), 'Type1';
is font-type($cid-keyed-font), 'CIDFontType0';
is font-type($ttc-font), 'TrueType';
# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');

lives-ok { $pdf.save-as: "t/fontobj.pdf"; };

done-testing;

