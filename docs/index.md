[![Actions Status](https://github.com/pdf-raku/PDF-Font-Loader-raku/workflows/test/badge.svg)](https://github.com/pdf-raku/PDF-Font-Loader-raku/actions)

[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)

## Name

PDF::Font::Loader

## Synopsis

```raku
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
```

## Description

This module provides font loading and handling for [PDF::Lite](https://pdf-raku.github.io/PDF-Lite-raku), [PDF::API6](https://pdf-raku.github.io/PDF-API6) and other PDF modules.

## Classes in this distribution

* [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader) - external font loader
* [PDF::Font::Loader::Dict](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Dict) - PDF font dictionary loader
* [PDF::Font::Loader::FontObj](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj) - Loaded basic font representation
  - [PDF::Font::Loader::FontObj::CID](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/FontObj/CID) - Loaded CID font representation
* [PDF::Font::Loader::Enc](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc) - Font encoder/decoder base class
  - [PDF::Font::Loader::Enc::Type1](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Type1) - Typical type-1 encodings (win mac std)
  - [PDF::Font::Loader::Enc::Identity16](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Identity16) - Identity-H/Identity-V 2 byte encoding
  - [PDF::Font::Loader::Enc::CMAP](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/CMap) - General CMap driven variable encoding
    - [PDF::Font::Loader::Enc::Unicode](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Enc/Unicode) - UTF-8, UTF-16 and UTF-32 specific encoding
* [PDF::Font::Loader::Glyph](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Glyph) - Glyph representation class
 
## Install

PDF::Font::Loader depends on:

- [Font::FreeType](https://pdf-raku.github.io/Font-FreeType-raku/) Raku module which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

- [FontConfig](https://pdf-raku.github.io/FontConfig/) library .

