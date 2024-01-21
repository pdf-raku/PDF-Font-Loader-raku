#| Implements a Type1 single byte encoding scheme, such as win, mac, or std
class PDF::Font::Loader::Enc::Type1 {

    use PDF::Content::Font::Enc::Type1;
    also is PDF::Content::Font::Enc::Type1;

    use PDF::Font::Loader::Enc;
    also is PDF::Font::Loader::Enc;

    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    use PDF::Content::Font::Encoder;
    also does PDF::Content::Font::Encoder;

}

=begin pod

=head2 Description

This is an early single byte encoding scheme that is restricted to a maximum of 255 glyphs.

It works best with latinish characters. However the encoding schema can be customized and adapted in the PDF, so it will work with any font as long
as no more that 255 unique glyphs are begin used.

Their are slightly varying `win`, `mac` and `std` encodings for text fonts, as well as significantly different `sym` encoding, commonly used for the `Symbol` core font, and `zapf` for the `ZapfDingbats` core-font.

=head2 Methods

This class inherits from L<PDF::Font::Loader::Enc> and has all its methods available.

=end pod
