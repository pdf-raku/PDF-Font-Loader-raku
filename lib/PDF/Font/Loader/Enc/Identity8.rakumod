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

    multi method encode(Str $hex-string, :$str! --> Str) {
        PDF::COS.coerce: :$hex-string;
    }
    multi method encode(Str $text) is default {
        my buf8 $codes .= new;;
        my $face-struct = $!face.raw;
        for $text.ords {
            my uint $index = $face-struct.FT_Get_Char_Index($_);
            @!to-unicode[$index] ||= $_;
            %!charset{$index} ||= $_;
            $codes.push: $index;
        }
        $codes;
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

    multi method decode(Str $encoded, :$str! --> Str) {
        $.decode($encoded)».chr.join;
    }
    multi method decode(Str $encoded --> buf8) {
        buf32.new: $encoded.ords.map({@!to-unicode[$_]}).grep: {$_};
    }
}
