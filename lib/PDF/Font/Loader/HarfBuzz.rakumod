#| HarfBuzz integration for PDF::Font::Loader
unit module PDF::Font::Loader::HarfBuzz;

use HarfBuzz::Font;
use HarfBuzz::Font::FreeType;
use HarfBuzz::Feature;
use HarfBuzz::Buffer;
use HarfBuzz::Raw::Defs :hb-direction;
use HarfBuzz::Shaper;

our sub make-harfbuzz-font(:$face!, :$font-buf!, Bool :$kern --> HarfBuzz::Font) {
    my HarfBuzz::Feature() @features = $kern ?? <kern> !! <-kern>;
    $face.font-format ~~ 'TrueType'|'OpenType'
        ?? HarfBuzz::Font.COERCE: %( :blob($font-buf), :@features )
        !! HarfBuzz::Font::FreeType.COERCE: %( :ft-face($face), :@features);
}

our sub make-harfbuzz-shaper(Str:D :$text!, HarfBuzz::Font:D :$font!, Str :$script, Str :$lang --> HarfBuzz::Shaper:D) {
    my HarfBuzz::Buffer $buf .= new: :$text, :direction(HB_DIRECTION_LTR);
    $buf.script = $_ with $script;
    $buf.language = $_ with $lang;
    HarfBuzz::Shaper.new: :$buf, :$font;
}
