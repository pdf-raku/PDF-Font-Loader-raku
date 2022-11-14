use PDF::Font::Loader;
use Font::FreeType;
use Font::FreeType::Face;
use PDF::Font::Loader::FontObj :EncodingScheme;
use PDF::Lite;

subset Encoding where EncodingScheme|!.defined;

sub MAIN(
    Str:D  $file!,
    Str:D  :$text = "Grumpy wizards make toxic brew for the evil Queen and Jack.",
    Str    :$save-as is copy,
    UInt:D :$font-size = 16,
    Bool   :$subset,
    Encoding :$enc,
) {
    my Blob:D $font-buf = $file.IO.slurp: :bin;
    my %opt = :$enc if $enc;
    my PDF::Font::Loader::FontObj:D $font = PDF::Font::Loader.load-font: :$font-buf, :$subset, |%opt;
    $save-as //= $font.face.postscript-name ~ '.pdf';
    my PDF::Lite $pdf .= new;
    my PDF::Lite::Page $page = $pdf.add-page;
    my $margin = 10;

    my @bbox = $page.media-box.List;
    my @position = @bbox[0] + $margin,
                   @bbox[3] - $margin - $font-size;
    my $width = @position[0] - @bbox[2] - $margin;
    my $height = @bbox[1] - @position[1] - $margin;
    

    $page.text: {
        .font = $font, $font-size;
        .text-position = @position;
        .say: $text
                 
    }
    note "saving as: " ~ $save-as;
    $pdf.save-as: $save-as;
}
