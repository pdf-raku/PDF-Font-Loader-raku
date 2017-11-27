class Font::PDF {

    use Font::FreeType;
    use Font::FreeType::Face;
    use Font::PDF::FreeType;
    use Font::PDF::Type1;
    subset TrueTypish of Font::FreeType::Face where .font-format eq 'TrueType'|'CFF';
    subset Type1ish of Font::FreeType::Face where .font-format eq 'Type 1';

    multi method load-font(Str $font-file!, |c) is default {
        my $free-type = Font::FreeType.new;
        my $font-stream = $font-file.IO.open(:r, :bin).slurp: :bin;
        my $face = $free-type.face($font-stream);
        self.load-font($face, :$font-stream, |c);
    }

    multi method load-font(TrueTypish $face, |c) {
        Font::PDF::FreeType.new( :$face, |c);
    }

    multi method load-font(Type1ish $face, |c) {
        Font::PDF::Type1.new( :$face, |c);
    }

    multi method load-font(Font::FreeType::Face $face, |c) {
        die "unsupported font format: {$face.font-format}";
    }

}

=begin pod

=head1 NAME

Font::PDF

=head1 SYNPOSIS

 use PDF::Lite;
 use PDF::Font;
 my $deja = Font::PDF.load-font("t/fonts/DejaVuSans.ttf");

 my PDF::Lite $pdf .= new;
 my $page = $pdf.add-page;
 $page.text: {
    .font = $deja;
    .text-position = [10, 760];
    .say: 'Hello, world';
 }
 $pdf.save-as: "/tmp/example.pdf";

=head1 DESCRIPTION

This module loads fonts for use by
PDF::Lite,  PDF::API6 and other PDF modules.

=head1 METHODS

=head3 load-font

 PDF::Font.load-font(Str $font-file, Str :$enc, Bool :$embed);

A class level method to create a new font object from a font file.

parameters:
=begin item
    C<$font-file>

    Font file to load. Currently supported formats are:
    =item2 Open-Type (C<.otf>)
    =item2 True-Type (C<.ttf>)
    =item2 True-Type Collections (C<.ttc>)
    =item2 Postscript (C<.pfb>, or C<.pfa>)

=end item

=begin item
C<$enc> - encoding scheme

=item C<win> - Win Ansi encoding (8 bit)
=item C<mac> - Max expert encoding (8 bit)
=item C<identity-h> - Identity-H encoding (16 bit)

=end item

An eight bit C<win>, or C<mac> encoding can be used as long as not more than 255
distinct characters are being used from the font.

=begin item
C<embed>

Embed the font in the PDF file (default: C<True>).
=end item

=head2 BUGS AND LIMITATIONS

=item Font subsetting is not yet implemented. Fonts are always embedded in their entirety.

=item Font formats are limited to Type1 (Postscript, True-Type and Open-Type.

=item This is a new module. There may be other bugs.

=end pod

