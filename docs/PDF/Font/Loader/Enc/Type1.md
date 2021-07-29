[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)
 :: [Type1](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Type1)

class PDF::Font::Loader::Enc::Type1
-----------------------------------

Implements a Type1 single byte encoding scheme, such as win, mac, or std

Description
-----------

This is an early single byte encoding scheme that is restricted to a maximum of 255 glyphs.

It works best with latinish characters. However the encoding schema can be customized and adapted in the PDF, so it will work with any font as long as no more that 255 unique glyphs are begin used.

Their are slightly varying `win`, `mac` and `std` encodings for text fonts, as well as significantly different `sym` encoding, commonly used for the `Symbol` core font, and `zapf` for the `ZapfDingbats` core-font.

Methods
-------

This class inherits from [PDF::Font::Loader::Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc) and has all its methods available.

