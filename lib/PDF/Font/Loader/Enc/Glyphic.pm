use PDF::Content::Font::Enc::Glyphic;

role PDF::Font::Loader::Enc::Glyphic
    does PDF::Content::Font::Enc::Glyphic {

  use Font::FreeType::Face;
  use Font::FreeType::Native;
  use Font::FreeType::Native::Types;
  has Font::FreeType::Face $.face is required;

  method lookup-glyph(UInt $chr-code) {
      $!face.glyph-name($chr-code.chr);
  }

  method glyph-map {
      return Mu
          unless $!face.has-glyph-names;
      my %codes;
      my FT_Face $struct = $!face.struct;  # get the native face object
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
