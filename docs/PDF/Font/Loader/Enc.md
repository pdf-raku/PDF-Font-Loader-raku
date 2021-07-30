[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)

class PDF::Font::Loader::Enc
----------------------------

Font encoder/decoder base class

Description
-----------

This is the base class for all encoding classes. It is suitable for fixed length encodings only such as `mac`, `win` (single byte) or `identity-h`.

[PDF::Font::Loader::Enc::CMap](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/CMap), which inherits from this class, is the base class for variable length encodings

Methods
-------

These methods are common to all encoding sub-classes

### has-encoding

True if the font has a Unicode mapping.

The Unicode encoding layer is optional by design in the PDF standard.

This method should be used on a font loaded from a PDF dictionary to ensure that it has an character encoding layer and `encode()` and `decode()` methods can be called on it.

### first-char

The first [CID](PDF::Font::Loader::Glyph#cid) in the fonts character-set.

last-char
---------

The last [CID](PDF::Font::Loader::Glyph#cid) in the fonts character-set.

### widths

```raku
method widths() returns Array[UInt]
```

The widths of all glyphs, indexed by CID, in the range `first-char` to `last-char`. The widths are in unscaled font units and should be multiplied by font-size / 1000 to compute actual widths.

### width

```raku
method width($cid) returns UInt
```

R/w accessor to get or sey the width of a character.

### glyph

```raku
method glyph(UInt $cid) returns PDF::Font::Loader::Glyph
```

Returns a [Glyph](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Glyph) object for the given CID index.

### method encode

```raku
multi method encode(Str $text, :cids($)!) returns Blob; # encode to CIDs
multi method encode(Str $text) returns PDF::COS::ByteString;            # encode to a byte-string
```

Encode a font from a Unicode text string. By default to byte-string.

The `:cids` option returns a Blob of CIDs, rather than a fully encoded bytes-string.

### method decode

```raku
multi method decode(Str $byte-string, :cids($)!) returns Seq; # decode to CIDs
multi method decode(Str $byte-string, :ords($)!) returns Seq; # decode to code-points
multi method decode(Str $byte-string) returns PDF::COS::ByteString;            # encode to a byte-string
```

Decodes a PDF byte string, by default to a Unicode text string.

### set-encoding

```raku
method set-encoding(UInt $code-point, UInt $cid)
```

Map a single Unicode code-point to a CID index. This method is most likely to be useful for manually setting up an encoding layer for a font loaded from a PDF that lacks an encoding layer(`has-encoding()` is `False`).

### make-to-unicode-cmap

Generates a CMap for the /ToUnicode entry in a PDF font. This method is typically called from the font object when an encoding has been added or updated for the encoder.

