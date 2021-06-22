use v6;
use PDF::Font::Loader :load-font;
use PDF::Content::FontObj;
use PDF::Lite;
use Test;

my PDF::Lite $pdf .= new;
my PDF::Content::FontObj $deja = load-font( :file<t/fonts/DejaVuSans.ttf>, :!subset );
my PDF::Content::FontObj $otf-font = load-font( :file<t/fonts/Cantarell-Oblique.otf>, :enc<win> );
my PDF::Content::FontObj $cff-font = load-font( :file<t/fonts/NimbusRoman-Regular.cff>, :enc<win> );
# True collections don't embed without subsetting
my PDF::Content::FontObj $ttc-font = load-font( :file<t/fonts/wqy-microhei.ttc>, :!embed, :!subset );

$pdf.add-page.text: {
   .font = $deja;
   .text-position = [10, 760];
   .say: 'Hello, world';
   .say: 'WAV', :kern;
   my $s;
   my $n = 0;
   .font = $deja, 8;
   $deja.face.forall-chars: :!load, -> $_ {
       last if .char-code > 19900;
       $s ~= .char-code.chr;
       $s ~= ' ' if $n++ %% 10
   };
   .say: $s, :width(400);
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
}

# ensure consistant document ID generation
$pdf.id =  $*PROGRAM-NAME.fmt('%-16s').substr(0,16);

lives-ok { $pdf.save-as: "t/freetype.pdf"; };

done-testing;

