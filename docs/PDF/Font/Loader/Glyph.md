[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Glyph](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Glyph)

class PDF::Font::Loader::Glyph
------------------------------

Represents a single glyph in a PDF

### Description

This is an introspective class for looking up glyphs from font encodings.

### Example

```raku
use PDF::Font::Loader::Glyph;

# load from character encodings
my PDF::Font::Loader::Glyph @glyphs = $font.glyphs: "Hi";
say @glyphs[0].raku; # Glyph.new(:name<H>, :code-point(72),  :cid(48), :gid(26), :dx(823), :dy(0))
say @glyphs[1].raku; # Glyph.new(:name<i>, :code-point(105), :cid(4),  :gid(21), :dx(334), :dy(0)

# load from CIDs
@glyphs = $font.glyphs: [48, 4];
```

### Methods

### code-point

The Unicode code-point for the glyph.

If the font has been loaded from a PDF dictionary. The glyph may not have a Unicode font mapping. In this case, `code-point` will be zero.

### name

Glyph name.

### cid

The PDF logical character identifier for the glyph

### gid

Actual glyph identifier for the glyph. This is the index into the font's associated `face` object.

For `Identity-H` and `Identity-V` encoded fonts and other fonts without a `cid-to-gid-map` table, the `gid` will be the same as the `cid`.

### dx

The width (horizontal displacement to the next glyph). The value should be multiplied by font-size / 1000 to compute the actual displacement.

Note that the width of a glyph can be indirectly set or altered via the font object:

`$font.glyph-width('i') -= 100`

### dy

The height (vertical displacement to the next glyph) for a vertically written glyph. This method is not-yet-implemented, and always returns zero.

