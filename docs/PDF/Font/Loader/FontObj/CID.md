[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj)
 :: [CID](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj/CID)

class PDF::Font::Loader::FontObj::CID
-------------------------------------

Implements a PDF CID font

Description
-----------

This is a subclass of [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) for representing PDF CID fonts, introduced with PDF v1.3.

The main defining characteristic of CID (Type0) fonts is their abililty to support multi-byte (usually 2-byte) encodings.

This class is used for all fonts with a multi-byte (or potentially multi-byte) encoding such as `identity-h` or `cmap`.

### Methods

This class inherits from [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) and has all its methods available.

It provides CIS specific implementations of the `finish-font`, `font-descriptor` and `make-dict` methods, but introduces no new methods.

