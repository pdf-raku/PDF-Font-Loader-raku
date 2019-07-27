use PDF::Content::Font::Enc::Type1;
use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Type1
    is PDF::Content::Font::Enc::Type1
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic
}
