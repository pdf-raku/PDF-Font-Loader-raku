#| Non CID (Glyphic based) encoding
use PDF::Content::Font::Enc::Glyphic;

role PDF::Font::Loader::Enc::Glyphic
    does PDF::Content::Font::Enc::Glyphic {

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;
    has Font::FreeType::Face $.face is required;
    use Font::AFM;

    has Hash $!glyph-map;

    # Callback for character mapped glyphs
    method lookup-glyph(UInt $ord) {
        my $glyph-name;
        if self.charset{$ord} -> $cid {
            if $.cid-to-gid-map[$cid] -> $gid {
                $glyph-name = $!face.glyph-name-from-index($gid);
            }
        }
        $glyph-name //= $!face.glyph-name($ord.chr) // '.notdef';
        # Not sure what glyph names are universally supported. This is conservative.
        $.encoding-updated = True
            unless $glyph-name ~~ %Font::AFM::Glyphs{$ord.chr};
        $glyph-name;
    }

    # Callback for unmapped glyphs
    method cid-map-glyph($glyph-name, $cid) {
        if $!face.index-from-glyph-name($glyph-name) -> $gid {
            $.cid-to-gid-map[$cid] ||= $gid;
        }
    }

    # build a maps for glyph names to characters
    # - see also PDF::Content::Font::Enc::Glyphic, which calls this
    method glyph-map {
      $!glyph-map //= do {
          my %codes;
          if $!face.has-glyph-names {
              my FT_Face $struct = $!face.raw;  # get the native face object
              my FT_UInt $gid;
              my FT_ULong $char-code = $struct.FT_Get_First_Char( $gid);
              while $gid {
                  my $char := $char-code.chr;
                  %codes{ $!face.glyph-name-from-index($gid) } = $char;
                  $char-code = $struct.FT_Get_Next_Char( $char-code, $gid);
              }
          }
          %codes;
      }
  }
}
