use PDF::Content::Font::Enc::Glyphic;

role PDF::Font::Loader::Enc::Glyphic
    does PDF::Content::Font::Enc::Glyphic {

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;
    has Font::FreeType::Face $.face is required;
    has Hash $!glyph-map;
    has %!cid-to-gid-map;

    # Callback for character mapped glyphs
    method lookup-glyph(UInt $chr-code) {
        $!face.glyph-name($chr-code.chr);
    }

    # Callback for unmapped glyphs
    method map-glyph($glyph-name, $cid) {
        if $!face.index-from-glyph-name($glyph-name) -> $gid {
            %!cid-to-gid-map{$cid} //= $gid;
        }
    }
    method cid-to-gid($cid) { %!cid-to-gid-map{$cid} // $cid }

    method glyph-map {
      $!glyph-map //= do {
          my %codes;
          if $!face.has-glyph-names {
              my FT_Face $struct = $!face.raw;  # get the native face object
              my FT_UInt $glyph-idx;
              my FT_ULong $char-code = $struct.FT_Get_First_Char( $glyph-idx);
              while $glyph-idx {
                  my $char := $char-code.chr;
                  %codes{ $!face.glyph-name-from-index($glyph-idx) } = $char;
                  $char-code = $struct.FT_Get_Next_Char( $char-code, $glyph-idx);
              }
          }
          %codes;
      }
  }

}
