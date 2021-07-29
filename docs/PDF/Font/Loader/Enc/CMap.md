[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)
 :: [CMap](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/CMap)

class PDF::Font::Loader::Enc::CMap
----------------------------------

CMap based encoding/decoding

### Description

This method maps to PDF font dictionaries with a `ToUnicode` entry and Type0 fonts with an `Encoding` entry that reference CMaps.

This class extends the base-class [PDF::Font::Loader::Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc), adding the ability of reading existing CMaps. It also adds the ability the handle variable encoding.

### Methods

This class inherits from [PDF::Font::Loader::Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc) and has all its method available.

### make-encoding-cmap

Generates a CMap for the /Encoding entry in a PDF Type0 font, which is used to implment custom variable and wide encodings.. This method is typically called from the font object when an encoding has been added or updated for the encoder.

### Caveats

Most, but not all, CMap encoded fonts have a Unicode mapping. The `has-encoding()` method should be used to verify this before using the `encode()` or `decode()` methods on a dictionary loaded CMap encoding.

