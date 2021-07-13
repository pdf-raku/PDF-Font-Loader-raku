use PDF::Font::Loader::Enc;

class PDF::Font::Loader::Enc::Identity8
    is PDF::Font::Loader::Enc {

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;

    has Font::FreeType::Face $.face is required;
    has uint16 @!to-unicode;
    has UInt %.charset{UInt};
    has UInt $.idx-mask;
    has Bool $!init;

    method is-wide { False }

    multi method encode(Str $text, :cids($)!) is default {
        my $face-struct = $!face.raw;
        buf8.new: $text.ords.map: {
            my uint $cid = $face-struct.FT_Get_Char_Index($_);
            @!to-unicode[$cid] ||= $_;
            %!charset{$cid} ||= $_;
            $cid;
        }
    }
    multi method encode(Str $hex-string --> Str) {
        PDF::COS.coerce: :$hex-string;
    }
    method !encode-cids(Str $text) {
    }

    method !setup-decoding {
        my FT_Face $struct = $!face.raw;  # get the native face object
        my FT_UInt $idx;
        my FT_ULong $char-code = $struct.FT_Get_First_Char( $idx);
        while $idx {
            @!to-unicode[$idx] = $char-code;
            $char-code = $struct.FT_Get_Next_Char( $char-code, $idx);
        }
    }

    multi method to-unicode {
        $!init //= do { self!setup-decoding; True }
        @!to-unicode;
    }

    multi method decode(Str $encoded, :cids($)! --> buf8) {
        $encoded.ords;
    }
    multi method decode(Str $encoded, :ords($)!) {
        $encoded.ords.map({@!to-unicode[$_]}).grep: {$_};
    }
    multi method decode(Str $encoded --> Str) {
        $.decode($encoded, :ords)».chr.join;
    }
}
