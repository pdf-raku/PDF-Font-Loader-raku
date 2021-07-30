#| /Identity-H or /Identity-V encoded fonts
use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Identity16
    is PDF::Font::Loader::Enc {

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;
    use PDF::COS;
    use PDF::IO::Util :&pack;

    has Font::FreeType::Face $.face is required;
    has uint32 @!to-unicode;
    has UInt %.charset{UInt};
    has UInt $.min-index;
    has UInt $.max-index;
    has Bool $!init;

    method is-wide {True}

    multi method encode(Str $text, :cids($)!) {
        my $face-struct = $!face.raw;
        blob16.new: $text.ords.map: -> $ord {
            my uint $cid = $face-struct.FT_Get_Char_Index($ord);
            @!to-unicode[$cid] ||= $ord;
            %!charset{$ord} ||= $cid;
            $cid;
        }
    }

    multi method encode(Str $text --> Str) {
        my blob8 $buf := pack(self.encode($text, :cids), 16);
        my $hex-string = $buf.decode: 'latin-1';
        PDF::COS.coerce: :$hex-string;
    }

    method !setup-decoding {
        my FT_Face $struct = $!face.raw;
        my FT_UInt $glyph-idx;
        my FT_ULong $char-code = $struct.FT_Get_First_Char( $glyph-idx);
        @!to-unicode[$!face.num-glyphs] = 0;
        while $glyph-idx {
            @!to-unicode[ $glyph-idx ] = $char-code;
            $char-code = $struct.FT_Get_Next_Char( $char-code, $glyph-idx);
        }
    }

    method to-unicode {
        $!init //= do { self!setup-decoding; True }
        @!to-unicode;
    }

    multi method decode(Str $encoded, :cids($)!) {
        $encoded.ords.map: -> \hi, \lo {hi +< 8 + lo};
    }

    multi method decode(Str $encoded, :ords($)!) {
        my @to-unicode := self.to-unicode;
        self.decode($encoded, :cids).map({@to-unicode[$_]}).grep: {$_};
    }

    multi method decode(Str $encoded --> Str) {
        $.decode($encoded, :ords)».chr.join;
    }
}

=begin pod

=head2 Description

This class implements`Identity-H` and `Identity-V` encoding.

This is common 2 byte encoding that directly encodes font glyph identifiers as
CIDs. It was introduced with PDF 1.3.

=end pod
