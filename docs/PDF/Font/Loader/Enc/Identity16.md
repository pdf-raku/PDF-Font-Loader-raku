[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)
 :: [Identity16](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Identity16)

class PDF::Font::Loader::Enc::Identity16
----------------------------------------

/Identity-H or /Identity-V encoded fonts

Description
-----------

This class implements`Identity-H` and `Identity-V` encoding.

This is common 2 byte encoding that directly encodes font glyph identifiers as CIDs. It was introduced with PDF 1.3.

