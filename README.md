[![Actions Status](https://github.com/pdf-raku/PDF-Font-Loader-raku/workflows/test/badge.svg)](https://github.com/pdf-raku/PDF-Font-Loader-raku/actions)

[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)

Name
----

PDF::Font::Loader

Synopsis
========

    # load a font from a file
    use PDF::Font::Loader :load-font;
    use PDF::Content::FontObj;

    my PDF::Content::FontObj $deja;
    $deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
    -- or --
    $deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

    # find/load system fonts; requires fontconfig
    use PDF::Font::Loader :load-font, :find-font;
    $deja = load-font( :family<DejaVu>, :slant<italic> );
    my Str $file = find-font( :family<DejaVu>, :slant<italic> );
    my PDF::Content::FontObj $deja-vu = load-font: :$file;

    # use the font to add text to a PDF
    use PDF::Lite;
    my PDF::Lite $pdf .= new;
    $pdf.add-page.text: {
       .font = $deja;
       .text-position = [10, 600];
       .say: 'Hello, world';
    }
    $pdf.save-as: "/tmp/example.pdf";

Description
-----------

This module provides font loading and handling for [PDF::Lite](https://pdf-raku.github.io/PDF-Lite-raku), [PDF::API6](https://pdf-raku.github.io/PDF-API6) and other PDF modules.

Methods
-------

### load-font

A class level method to create a new font object.

#### `PDF::Font::Loader.load-font(Str :$file, Bool :$subset, :$enc, :$lang, :$dict);`

Loads a font file.

parameters:

  * `:$file`

    Font file to load. Currently supported formats are:

      * OpenType (`.otf`)

      * TrueType (`.ttf`)

      * Postscript (`.pfb`, or `.pfa`)

      * CFF (`.cff`)

    TrueType Collections (`.ttc`) are also accepted, but must be subsetted, if they are being embedded.

  * `:$subset` *(experimental)*

    Subset the font for compaction. The font is reduced to the set of characters that have actually been encoded. This can greatly reduce the output size when the font is embedded in a PDF file.

    This feature currently works on OpenType or TrueType fonts and requires installation of the experimental [HarfBuzz::Subset](HarfBuzz::Subset) module.

  * `:$enc`

    Selects the encoding mode: common modes are `win`, `mac` and `identity-h`.

      * `mac` Macintosh platform single byte encoding

      * `win` Windows platform single byte encoding

      * `identity-h` a degenerative two byte encoding mode

    `win` is used as the default encoding for fonts with no more than 255 glyphs. `identity-h` is used otherwise.

    It is recommended that you set a single byte encoding such as `:enc<mac>` or `:enc<win>` when it known that no more that 255 distinct characters will actually be used from the font within the PDF.

  * `:$dict`

    Associated font dictionary.

#### `PDF::Font::Loader.load-font(Str :$family, Str :$weight, Str :$stretch, Str :$slant, Bool :$subset, Str :$enc, Str :$lang);`

    my $vera = PDF::Font::Loader.load-font: :family<vera>;
    my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :stretch<condensed> :slant<italic>);

Loads a font by a fontconfig name and attributes.

Note: Requires fontconfig to be installed on the system.

parameters:

  * `:$family`

    Family name of an installed system font to load.

  * `:$weight`

    Font weight, one of: `thin`, `extralight`, `light`, `book`, `regular`, `medium`, `semibold`, `bold`, `extrabold`, `black` or a number in the range `100` .. `900`.

  * `:$stretch`

    Font stretch, one of: `normal`, `ultracondensed`, `extracondensed`, `condensed`, or `expanded`

  * `:$slant`

    Font slat, one of: `normal`, `oblique`, or `italic`

  * `:$lang`

    A RFC-3066-style language tag. `fontconfig` will select only fonts whose character set matches the preferred lang. See also [I18N::LangTags](https://modules.raku.org/dist/I18N::LangTags:cpan:UFOBAT).

### find-font

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
              );

Locates a matching font-file. Doesn't actually load it.

    my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
    say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
    my $font = PDF::Font::Loader.load-font: :$file;

PDF::Font::Loader::FontObj Methods
----------------------------------

The following methods are available on the loaded font:

Font Object Methods -----------------

### font-name

The font name

### height

Overall font height

### encode

Encodes strings

### decode

    -

Decodes buffers

### kern

Kern text via the font's kerning tables. Returns chunks of text separated by numeric kern widths.

```raku
say $font.kern("ABCD"); # ["AB", -18, "CD"]
```

### glyph-width

Return the width of a glyph. This is a `rw` method that can be used to globally adjust a font's glyph spacing for rendering and string-width calculations:

```raku
say $vera.glyph-width('V'); # 684;
$vera.glyph-width('V') -= 100;
say $vera.glyph-width('V'); # 584;
```

### to-dict

Produces a draft PDF font dictionary.

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

### face

[Font::FreeType::Face](https://pdf-raku.github.io/Font-FreeType-raku/Font/FreeType/Face) object associated with the font.

If the font was loaded from a `$dict` object and `is-embedded` is true, the `face` object has been loaded from the embedded font, otherwise its a system-loaded font, selected to match the font.

### glyphs

```raku
use PDF::Font::Loader::Glyph;
my PDF::Font::Loader::Glyph @glyphs = $font.glyphs: "Hi";
say "name:{.name} code:{.code-point.raku} cid:{.cid} gid:{.gid} dx:{.dx} dy:{.dy}"
    for @glyphs;
```

Maps a string to a set of glyphs:

  * `name` is a glyph name

  * `code-point` is a character code mapping

  * `cid` is the encoded value

  * `gid` is the font index of the glyph in the font object`s `face` attribute.

  * `dx` and `dy` are unscaled font sizes. They should be multiplied by the current font-size/1000 to get the actual sizes.

Loading PDF Fonts ---------------

Fonts can also be loaded from PDF font dictionaries. The following example loads and summarizes page-level fonts:

```raku
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::Font;
use PDF::Content::FontObj;

constant Fmt = "%-30s %-8s %-10s %-3s %-3s";
sub yn($_) {.so ?? 'yes' !! 'no' }

my %SeenFont{PDF::Content::Font};
my PDF::Lite $pdf .= open: "t/freetype.pdf";
say sprintf(Fmt, |<name type encode emb sub>);
say sprintf(Fmt, |<-------------------------- ------- ---------- --- --->);
for 1 .. $pdf.page-count {
    my PDF::Content::Font %fonts = $pdf.page($_).gfx.resources('Font');

    for %fonts.values -> $dict {
        unless %SeenFont{$dict}++ {
            my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$dict, :quiet;
            say sprintf(Fmt, .font-name, .type, .encoding, .is-embedded.&yn, .is-subset.&yn)
                given $font;
        }
    }
}
```

Produces:

    name                      |     type    |  encode    | emb | sub
    --------------------------+-------------+------------+-----+---
    DejaVuSans                |    Type0    | identity-h | yes | no 
    Times-Roman               |    Type1    | win        | no  | no 
    WenQuanYiMicroHei         |    TrueType | win        | no  | no 
    NimbusRoman-Regular       |    Type1    | win        | yes | no 
    Cantarell-Oblique         |    Type1    | win        | yes | no

Install
-------

  * PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

  * Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) library and command-line tools is strongly recommended.

