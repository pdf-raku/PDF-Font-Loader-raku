[[Raku PDF Project]](https://pdf-raku.github.io)
 / [[PDF-Font-Loader Module]](https://pdf-raku.github.io/PDF-Font-Loader-raku)
 / [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader)
 :: [Dict](https://pdf-raku.github.io/PDF-Font-Loader-raku/PDF/Font/Loader/Dict)

class PDF::Font::Loader::Dict
-----------------------------

Loads a font from a PDF font dictionary (experimental)

Description
-----------

Loads fonts from PDF font dictionaries.

Example
-------

The following example loads and summarizes page-level fonts:

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

