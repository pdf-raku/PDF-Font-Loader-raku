[![Build Status](https://travis-ci.org/p6-pdf/PDF-Font-p6.svg?branch=master)](https://travis-ci.org/p6-pdf/PDF-Font-p6)

NAME
====

PDF::Font

SYNPOSIS
========

    use PDF::Lite;
    use PDF::Font;
    my $deja = PDF::Font.load-font("t/fonts/DejaVuSans.ttf");

    my PDF::Lite $pdf .= new;
    my $page = $pdf.add-page;
    $page.text: {
       .font = $deja;
       .text-position = [10, 760];
       .say: 'Hello, world';
    }
    $pdf.save-as: "/tmp/example.pdf";

DESCRIPTION
===========

This module loads fonts for use by PDF::Lite, PDF::API6 and other PDF modules.

METHODS
=======

### load-font

    PDF::Font.load-font(Str $font-file, Str :$enc, Bool :$embed);

A class level method to create a new font object from a font file.

parameters:

  *     C<$font-file>

      Font file to load. Currently supported formats are:

        * Open-Type (`.otf`)

        * True-Type (`.ttf`)

        * True-Type Collections (`.ttc`)

        * Postscript (`.pfb`, or `.pfa`)

  * `$enc` - encoding scheme

      * `win` - Win Ansi encoding (8 bit)

      * `mac` - Max expert encoding (8 bit)

      * `identity-h` - Identity-H encoding (16 bit)

An eight bit `win`, or `mac` encoding can be used as long as not more than 255 distinct characters are being used from the font.

  * `embed`

    Embed the font in the PDF file (default: `True`).

BUGS AND LIMITATIONS
--------------------

  * Font subsetting is not yet implemented.

  * Font formats are limited to Type1 (Postscript, True-Type and Open-Type.

  * This is a new module. There may be other bugs.
