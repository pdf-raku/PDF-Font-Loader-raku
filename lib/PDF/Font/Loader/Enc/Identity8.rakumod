use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Identity8
    is PDF::Font::Loader::Enc {

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;

    has UInt %.charset{UInt};
    has UInt %!from-unicode{UInt};
    has uint16 @!to-unicode;
    has UInt $.idx-mask;
    has Bool $!init;

    method !setup-decoding(Font::FreeType::Face :$face!) {
        my FT_Face $struct = $face.raw;  # get the native face object
        my FT_UInt $idx;
        my FT_ULong $char-code = $struct.FT_Get_First_Char( $idx);
        $!idx-mask = ($idx div 256) * 256;
        while $idx {
            my uint8 $i = $idx - $!idx-mask;
            @!to-unicode[$i] = $char-code;
            %!from-unicode{$char-code} = $i;
            $char-code = $struct.FT_Get_Next_Char( $char-code, $idx);
        }
    }

    multi method to-unicode(:subset($) where .so) {
        if $!init {
            @!to-unicode = ();
            @!to-unicode[.key] = .value
                for %!charset.pairs;
            $!init = False;
        }
        @!to-unicode;
    }
    multi method to-unicode {
        $!init //= do { self!setup-decoding; True }
        @!to-unicode;
    }
    multi method encode(Str $text, :$str! --> Str) {
        self.encode($text).decode: 'latin-1';
    }
    multi method encode(Str $text --> buf8) is default {
        buf8.new: $text.ords.map({
            my $idx := %!from-unicode{$_};
            %!charset{$idx} ||= $_ if $idx;
            $idx;
        }).grep: {$_};
    }

    multi method decode(Str $encoded, :$str! --> Str) {
        $encoded.ords.map({@!to-unicode[$_]}).grep({$_})».chr.join;
    }
    multi method decode(Str $encoded --> buf8) {
        buf8.new: $encoded.ords.map({@!to-unicode[$_]}).grep: {$_};
    }
}
