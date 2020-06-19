[![Build Status](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6.svg?branch=master)](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6)

NAME
====

PDF::Font::Loader

SYNPOSIS
========

    # load a font from a file
    use PDF::Font::Loader :load-font;

    my $deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
    my $deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

    # find/load system fonts; requires fontconfig
    use PDF::Font::Loader :load-font, :find-font;
    $deja = load-font( :family<DejaVu>, :slant<italic> );
    my Str $file = find-font( :family<DejaVu>, :slant<italic> );
    my $deja-vu = load-font: :$file;

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

This module provdes font loading and handling for [PDF::Lite](PDF::Lite), [PDF::API6](PDF::API6) and other PDF modules.

METHODS
=======

### load-font

A class level method to create a new font object.

#### `PDF::Font::Loader.load-font(Str :$file);`

Loads a font file.

parameters:

  * `:$file`

    Font file to load. Currently supported formats are:

        * Open-Type (`.otf`)

        * True-Type (`.ttf`)

        * Postscript (`.pfb`, or `.pfa`)

#### `PDF::Font::Loader.load-font(Str :$family);`

    my $vera = PDF::Font::Loader.load-font: :family<vera>;
    my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :width<condensed> :slant<italic>);

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
              );

Locates a matching font-file. Doesn't actually load it.

    my $file = PDF::Font::Loader.find-font(:family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>);
    say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
    my $font = PDF::Font::Loader.load-font( :$file )';

INSTALL
=======

- PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

- Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) package and command-line tools is strongly recommended.

BUGS AND LIMITATIONS
====================

  * Font subsetting is not yet implemented. I.E. fonts are always fully embedded, which may result in large PDF files.

