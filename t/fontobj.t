use v6;
use PDF::Font::Loader :&load-font;
use PDF::Content::FontObj;
use PDF::Lite;
use Test;

my PDF::Lite $pdf .= new;
my PDF::Content::FontObj $deja = load-font( :file<t/fonts/DejaVuSans.ttf>, :!subset );
my PDF::Content::FontObj $otf-font = load-font( :file<t/fonts/Cantarell-Oblique.otf>, :enc<win> );
my PDF::Content::FontObj $cff-font = load-font( :file<t/fonts/NimbusRoman-Regular.cff>, :enc<win> );
# True collections don't embed without subsetting
my PDF::Content::FontObj $ttc-font = load-font( :file<t/fonts/wqy-microhei.ttc>, :!embed, :!subset );

is $deja.underline-position, -175;
is $deja.underline-thickness, 90;

my $n = 0;
my $all-chars;

$deja.face.forall-chars: :!load, -> $_ {
    $all-chars ~= .char-code.chr;
    $all-chars ~= ' ' if ++$n %% 100;
};

$pdf.add-page.text: {
   .font = $deja;
   .text-position = [10, 760];
   .say: 'Hello, world';
   .say: 'WAV', :kern;
   my $n = 0;
   .font = $deja, 8;

   .say: $all-chars, :width(400);
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

