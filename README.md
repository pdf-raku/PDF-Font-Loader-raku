[![Build Status](https://travis-ci.org/pdf-raku/PDF-Font-Loader-raku.svg?branch=master)](https://travis-ci.org/pdf-raku/PDF-Font-Loader-raku)

[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)

NAME
====

PDF::Font::Loader

SYNPOSIS
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

DESCRIPTION
===========

This module provdes font loading and handling for [PDF::Lite](https://pdf-raku.github.io/PDF-Lite-raku), [PDF::API6](https://pdf-raku.github.io/PDF-API6) and other PDF modules.

METHODS
=======

### load-font

A class level method to create a new font object.

#### `PDF::Font::Loader.load-font(Str :$file, Bool :$subset, :$enc, $lang);`

Loads a font file.

parameters:

  * `:$file`

    Font file to load. Currently supported formats are:

      * Open-Type (`.otf`)

      * True-Type (`.ttf`)

      * Postscript (`.pfb`, or `.pfa`)

      * CFF (`.cff`)

  * `:$subset` *(experimental)*

    Whether to subset the font for compaction. The font is reduced to the set of characters that have been actually been encoded. This can greatly reduce the output size of the generated PDF file.

    This feature currently works on OpenType or TrueType fonts and requires installation of the experimental [HarfBuzz::Subset](https://pdf-raku.github.io/HarfBuzz-Subset-raku/HarfBuzz/Subset) module.

  * `:$enc`

    Selects the encoding mode: common modes are `win`, `mac` and `identity-h`.

      * `mac` Macintosh platform single byte encoding

      * `win` Windows platform single byte encoding

      * `identity-h` a degenerative two byte encoding mode

    `win` is used as the default encoding for fonts with no more than 255 glyphs. `identity-h` is used otherwise.

    It is recommended that you set a single byte encoding such as `:enc<mac>` or `:enc<win>` when it known that no more that 255 distinct characters will actually be used from the font within the PDF.

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
    method find-font(Str :$family,     # e.g. :family<vera>
              Weight  :$weight,
              Stretch :$stretch,
              Slant   :$slant,
              Str     :$lang,   # e.g. :lang<jp>
              );

Locates a matching font-file. Doesn't actually load it.

    my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
    say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
    my $font = PDF::Font::Loader.load-font: :$file;

INSTALL
=======

- PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

- Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) library and command-line tools is strongly recommended.

