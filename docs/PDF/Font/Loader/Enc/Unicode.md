[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)
 :: [Unicode](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Unicode)

class PDF::Font::Loader::Enc::Unicode
-------------------------------------

UTF-8/16/32 based encoding and decoding (Experimental)

Description
-----------

This is an experimental class which implements partial support UTF-8, UTF-16 and UTF-32 encoding.

At this stage it only support named encodings with `UTF8`, `UTF16` and `UTF32` in the name.

### Methods

This class is based on [PDF::Font::Loader::Enc::CMap](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/CMap) and has all its methods available, except for `make-to-unicode-cmap`, which dies with a X::NYI error.

