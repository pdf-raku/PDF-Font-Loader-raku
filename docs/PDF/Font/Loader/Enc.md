[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc)

class PDF::Font::Loader::Enc
----------------------------

Font encoder/decoder base class

Description
-----------

This is the base class for all encoding classes.

Methods
-------

These methods are common to all encoding sub-clasess

### first-char

The first [CID](PDF::Font::Loader::Glyph#cid) in the fonts character-set.

last-char
---------

The last [CID](PDF::Font::Loader::Glyph#cid) in the fonts character-set.

### widths

The widths of all glyphs, indexed by CID, in the range `first-char` to `last-char`.

### glyph

```raku
method glyph(UInt $cid) returns PDF::Font::Loader::Glyph
```

Returns a [Glyph](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Glyph) object for the given CID index.

### make-cmap

Generates a CMap for inclusion in a PDF. This method is typically called from the font object when an encoding has been added or updated for the encoder.

