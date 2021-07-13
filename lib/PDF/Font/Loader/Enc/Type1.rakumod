#| Implements a Type1 single byte encoding scheme, such as win, mac, or std
use PDF::Content::Font::Enc::Type1;
use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Type1
    is PDF::Content::Font::Enc::Type1
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic
}
