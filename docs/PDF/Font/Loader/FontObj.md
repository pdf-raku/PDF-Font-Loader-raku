[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj)

class PDF::Font::Loader::FontObj
--------------------------------

Loaded font objects

Methods
-------

### font-name

The font name

### height

Overall font height

### encode

Encodes strings

### decode

Decodes buffers

### kern

Kern text via the font's kerning tables. Returns chunks of text separated by numeric kern widths.

```raku
say $font.kern("ABCD"); # ["AB", -18, "CD"]
```

### shape

Shape fonts via [PDF::Font::Loader::HarfBuzz](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/HarfBuzz). Returns encoded chunks, separated by 2-dimensional kern widths and heights.

```raku
say $font.shape("ABCD"); # ["AB", -18+0i, "CD"]
```

### glyph-width

Return the width of a glyph. This is a `rw` method that can be used to globally adjust a font's glyph spacing for rendering and string-width calculations:

```raku
say $vera.glyph-width('V'); # 684;
$vera.glyph-width('V') -= 100;
say $vera.glyph-width('V'); # 584;
```

### to-dict

Produces a draft PDF font dictionary. cb-finish() needs to be called to finalize it.

### cb-finish

Finishing hook for the PDF tool-chain. This produces a finalized PDF font dictionary, including embedded fonts, character widths and encoding mappings.

### is-embedded

Whether a font-file is embedded.

### is-subset

Whether the font has been subsetting

### is-core-font

Whether the font is a core font

### has-encoding

Whether the font has unicode encoding. This is needed to encode or extract text.

### underline-position

Position, from the baseline where an underline should be drawn. This is usually negative and should be multipled by the font-size/1000 to get the actual position.

### underline-thickness

Recommended underline thickness for the font. This should be multipled by font-size/1000.

### face

[Font::FreeType::Face](https://pdf-raku.github.io/Font-FreeType-raku/Font/FreeType/Face) object associated with the font.

If the font was loaded from a `$dict` object and `is-embedded` is true, the `face` object has been loaded from the embedded font, otherwise its a system-loaded font, selected to match the font.

### stringwidth

```raku
method stringwidth(Str $text, Numeric $point-size?, Bool :$kern) returns Numeric
```

Returns the width of the string passed as argument.

By default the computed size is in 1000's of a font unit. Alternatively second `point-size` argument can be used to scale the width according to the font size.

The `:kern` option can be used to adjust the stringwidth, using the font's horizontal kerning tables.

### get-glyphs

```raku
use PDF::Font::Loader::Glyph;
my PDF::Font::Loader::Glyph @glyphs = $font.get-glyphs: "Hi";
say "name:{.name} code:{.code-point} cid:{.cid} gid:{.gid} dx:{.dx} dy:{.dy}"
    for @glyphs;
```

Maps a string to glyphs, of type [PDF::Font::Loader::Glyph](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Glyph).

