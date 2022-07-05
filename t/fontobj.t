use v6;
use PDF::Font::Loader :&load-font;
use PDF::Content::FontObj;
use PDF::Lite;
use Test;

my PDF::Lite $pdf .= new;
my PDF::Content::FontObj $vera     = load-font :file<t/fonts/Vera.ttf>, :!subset;
my PDF::Content::FontObj $otf-font = load-font :file<t/fonts/Cantarell-Oblique.otf>, :enc<win>;
my PDF::Content::FontObj $cff-font = load-font :file<t/fonts/NimbusRoman-Regular.cff>, :enc<win>;
# True collections don't embed without subsetting
my PDF::Content::FontObj $ttc-font = load-font :file<t/fonts/Sitka.ttc>, :!embed, :!subset;

is $vera.underline-position, -284;
is $vera.underline-thickness, 143;

my $n = 0;
my $all-chars;

$vera.face.forall-chars: :!load,  {
    $all-chars ~= .char-code.chr;
    $all-chars ~= ' ' if ++$n %% 64;
};

$pdf.add-page.text: {
   .font = $vera;
   .text-position = [10, 760];
   .say: 'Hello, world';
   .say: 'WAV', :kern;
   .font = $vera, 12;

   .say: $all-chars, :width(300);
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
   .font = .core-font: 'Times';
   .say: "Core Font (Times)";
   .say: 'Grumpy wizards make toxic brew for the evil Queen and Jack';
}

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');

lives-ok { $pdf.save-as: "t/fontobj.pdf"; };

done-testing;

