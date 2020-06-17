use PDF::Content::Font::Enc::Glyphic;

role PDF::Font::Loader::Enc::Glyphic
    does PDF::Content::Font::Enc::Glyphic {

  use Font::FreeType::Face;
  use Font::FreeType::Raw;
  use Font::FreeType::Raw::Defs;
  has Font::FreeType::Face $.face is required;
  has Hash $!glyph-map;

  method lookup-glyph(UInt $chr-code) {
      $!face.glyph-name($chr-code.chr);
  }

  method glyph-map {
      return Mu
          unless $!face.has-glyph-names;
      $!glyph-map //= do {
          my %codes;
          my FT_Face $struct = $!face.raw;  # get the native face object
          my FT_UInt $glyph-idx;
          my FT_ULong $char-code = $struct.FT_Get_First_Char( $glyph-idx);
          while $glyph-idx {
              my $char := $char-code.chr;
              %codes{ $!face.glyph-name($char) } = $char;
              $char-code = $struct.FT_Get_Next_Char( $char-code, $glyph-idx);
          }
          %codes;
      }
  }

}
