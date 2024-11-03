[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)

Name
----

PDF::Font::Loader

Synopsis
========

```raku
# load a font from a file
use PDF::Font::Loader :&load-font;
use PDF::Content::FontObj;

my PDF::Content::FontObj $deja;
$deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
-- or --
$deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

# find/load the best matching system font
# *** requires FontConfig ***
use PDF::Font::Loader :load-font, :find-font;
$deja = load-font( :family<DejaVu>, :slant<italic> );
my Str $file = find-font( :family<DejaVu>, :slant<italic> );
my PDF::Content::FontObj $deja-vu = load-font: :$file;

# use the font to add text to a PDF
use PDF::Lite;
my PDF::Lite $pdf .= new;
$pdf.add-page.text: {
   .font = $deja, 12;
   .text-position = [10, 600];
   .say: 'Hello, world';
}
$pdf.save-as: "/tmp/example.pdf";
```

Description
-----------

This module provides font loading and handling for [PDF::Lite](https://pdf-raku.github.io/PDF-Lite-raku), [PDF::API6](https://pdf-raku.github.io/PDF-API6) and other PDF modules.

Methods
-------

### load-font

A class level method to load a font from a font file, or pattern creating a new [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) object.

```raku
multi method load-font(Str:D :$file, Bool :$subset, :$enc, :$dict);
```

Loads a font from a given font file as a [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) object.

```raku
multi method load-font(Bool :$subset, :$enc, :$lang, :$core-font, *%patt);
```

Finds the best matching font using the `find-font` method on a pattern and loads it. If `:core-font` is True and the pattern matches a core-font, it is loaded as a [PDF::Content::Font::CoreFont](https://pdf-raku.github.io/PDF-Content-raku/PDF/Content/Font/CoreFont) object.

parameters:

  * `:$file`

    Font file to load. Currently supported formats are:

      * OpenType (`.otf`)

      * TrueType (`.ttf`)

      * Postscript (`.pfb`, or `.pfa`)

      * CFF (`.cff`)

    TrueType Collections (`*.ttc`) and OpenType Collections (`*.otc`) are also accepted, but must be subsetted, if they are being embedded.

  * `:$subset`

    Subset the font for compaction. The font is reduced to the set of characters that have actually been encoded. This can greatly reduce the output size when the font is embedded in a PDF file.

    This feature currently works on OpenType, TrueType and CFF fonts and requires installation of the [HarfBuzz::Subset](https://harfbuzz-raku.github.io/HarfBuzz-Subset-raku/HarfBuzz/Subset) module.

  * `:$enc`

    Selects the encoding mode: common modes are `win`, `mac` and `identity-h`.

      * `mac` Macintosh platform single byte encoding

      * `win` Windows platform single byte encoding

      * `identity-h` a two byte encoding mode

    `win` is used as the default encoding for fonts with no more than 255 glyphs. `identity-h` is used otherwise.

    It is recommended that you use a single byte encoding such as `:enc<mac>` or `:enc<win>` when it known that no more that 255 distinct characters will actually be used from the font within the PDF.

  * `:$dict`

    Associated font dictionary.

  * `:$core-font`

    Prefer to load simple Type1 objects as [PDF::Content::Font::CoreFont](https://pdf-raku.github.io/PDF-Content-raku/PDF/Content/Font/CoreFont), rather than [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) (both perform the [PDF::Content::FontObj](https://pdf-raku.github.io/PDF-Content-raku/PDF/Content/FontObj) role).

#### `PDF::Font::Loader.load-font(Str :$family, Str :$weight, Str :$stretch, Str :$slant, Bool :$core-font, Bool :$subset, Str :$enc, Str :$lang);`

    my $vera = PDF::Font::Loader.load-font: :family<vera>;
    my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :stretch<condensed> :slant<italic>);

Finds and loads the best-matching system font via [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig).

Note: This method requires the Raku [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) module to be installed, unless the `:core-font` option is used, to load only PDF core fonts.

parameters:

  * `:$family`

    Family name of an installed system font to load.

  * `:$weight`

    Font weight, one of: `thin`, `extralight`, `light`, `book`, `regular`, `medium`, `semibold`, `bold`, `extrabold`, `black` or a number in the range `100` .. `900`.

  * `:$stretch`

    Font stretch, one of: `normal`, `ultracondensed`, `extracondensed`, `condensed`, or `expanded`

  * `:$slant`

    Font slant, one of: `normal`, `oblique`, or `italic`

  * `:$core-font`

    Bypass [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) and load matching [PDF::Content::Font::CoreFont](https://pdf-raku.github.io/PDF-Content-raku/PDF/Content/Font/CoreFont) objects, rather than [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) objects (both perform the [PDF::Content::FontObj](https://pdf-raku.github.io/PDF-Content-raku/PDF/Content/FontObj) role).

  * `:$lang`

    A RFC-3066-style language tag. [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) will select only fonts whose character set matches the preferred lang. See also [I18N::LangTags](https://modules.raku.org/dist/I18N::LangTags:cpan:UFOBAT).

  * `*%props`

    Any additional options are parsed as [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) properties.

### find-font

```raku
use PDF::Font::Loader
    :Weight  # thin|extralight|light|book|regular|medium|semibold|bold|extrabold|black|100..900
    :Stretch # normal|[ultra|extra]?[condensed|expanded]
    :Slant   # normal|oblique|italic
;
find-font(Str :$family,     # e.g. :family<vera>
          Weight  :$weight,
          Stretch :$stretch,
          Slant   :$slant,
          Str     :$lang,   # e.g. :lang<jp>
          Bool    :$all,
          UInt    :$best,
          Bool    :$serif,  # serif(True) or sans-serif(False) fonts
          *%pattern,
          );
```

This method requires the optional [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) Raku module to be installed.

Locates, font-files after sorting system fonts using the pattern. Normally the best matching font-file is returned, or multiple font files can be returned using the `:best($n)` or `:all` options.

```raku
my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
my $font = PDF::Font::Loader.load-font: :$file;
```

The `:all` option returns a sequence of all fonts, ordered by best to worst matching. This method may be useful, if you wish to apply your own selection critera.

The `:best($n)` is similar to `:all`, but returns at most the `$n` best matching fonts.

Any additional options are treated as a [FontConfig](https://pdf-raku.github.io/FontConfig-raku/FontConfig) pattern attributes. For example `:spacing<mono>` will select monospace fonts.

```raku
use PDF::Font::Loader;
use Font::FreeType;
use Font::FreeType::Face;
my Font::FreeType $ft .= new;
my $series = PDF::Font::Loader.find-font(:best(10), :!serif, :weight<bold>,);
my Str @best = $series.Array;
# prefer a font with kerning
my Str $best-font = @best.first: -> $file {
    my Font::FreeType::Face $face = $ft.face: $file;
    $face.has-kerning;
}
# fall-back to best matching font without kerning
$best-font //= @best.head;

note "best font: " ~ $best-font;
```

### can-subset

```raku
multi method can-subset returns Bool;
```

Returns `True` if [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader) is capable of font subsetting; I.E. the optional [HarfBuzz::Subset](https://harfbuzz-raku.github.io/HarfBuzz-Subset-raku/HarfBuzz/Subset) module has been installed.

```raku
multi method can-subset(IO() $font-file) returns Bool;
```

Returns `True` if [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader) has font subsetting capability for the particular font.

This will usually be be `True` for `TrueType` and `OpenType` fonts (extensions `.ttf`, `.otf`, `.ttc`, and `.otc`), if the optional [HarfBuzz::Subset](https://harfbuzz-raku.github.io/HarfBuzz-Subset-raku/HarfBuzz/Subset) module has been installed.

