use Test;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;
use HarfBuzz::Raw::Defs :hb-script;

my PDF::Lite $pdf .= new;
$pdf.add-page.text: -> $gfx {
    $gfx.text-position = 50, 700;

    my %french = (
        :text("ficellé fffffi. VAV."),
        :lang<fr>,
        :script(HB_SCRIPT_LATIN),
        :direction<ltr>
    );

    my %hindi = (
        :text("हालाँकि प्रचलित रूप पूजा"),
        :script(HB_SCRIPT_DEVANAGARI),
        :direction<ltr>,
        :lang<hi>,
        :font<Sanskrit2003.ttf>;
    );

    my %russian = (
        :text("Дуо вёжи дёжжэнтиюнт ут"),
        :lang<ru>,
        :script(HB_SCRIPT_CYRILLIC),
        :direction<ltr>,
    );

    my %arabic = (
        :text("تسجّل يتكلّم"),
        :lang<ar>,
        :script(HB_SCRIPT_ARABIC),
        :direction<rtl>,
        :font<amiri-regular.ttf>
    );

    for  %french, %hindi, %russian, %arabic {
        my $text = .<text>;
        my $direction = .<direction>;
        my $file = 't/fonts/' ~ (.<font> // 'DejaVuSans.ttf');

        my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$file;
        $gfx.font = $font;
        $gfx.say: $text, :shape, :$direction, :align<left>;
        $gfx.say;
    }
}

# ensure consistant document ID generation
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok {
    $pdf.save-as: "t/shape+script.pdf";
}

done-testing;
