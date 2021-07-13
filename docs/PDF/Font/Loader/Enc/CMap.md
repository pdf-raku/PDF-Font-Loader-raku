[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)
 :: [CMap](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/CMap)

class PDF::Font::Loader::Enc::CMap
----------------------------------

CMap based encoding/decoding

### Description

This method maps to PDF font dictionaries with a `ToUnicode` entry that references a CMap.

### Caveats

Most, but not all, CMap encoded fonts have a Unicode mapping. The `has-encoding()` method should be used to verify this before using the `encode()` or `decode()` methods on a dictionary loaded CMap encoding.

Bugs / Limitations
------------------

Currently, this class:

  * can read, but not write variable width CMap encodings.

  * only handles one or two byte encodings

