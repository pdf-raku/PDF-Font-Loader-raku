use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Identity16::Compact
    is PDF::Font::Loader::Enc {

    use PDF::COS;
    # char to glyph index mapping (built on the fly)
    has UInt %.charset{UInt};
    has uint32 @.to-unicode;

    multi method encode(Str $text, :$str! --> Str) {
        my $hex-string = self.encode($text).decode: 'latin-1';
        PDF::COS.coerce: :$hex-string;
    }
    multi method encode(Str $text) is default {
        my uint16 @codes;
        for $text.ords {
            my uint $index = (%!charset{$_} //= +%!charset + 1);
            @!to-unicode[$index] ||= $_;
            @codes.push: $index;
        }
        @codes;
    }

    multi method decode(Str $encoded, :$str! --> Str) {
        $.decode($encoded).map({.chr}).join;
    }
    multi method decode(Str $encoded --> buf32) {
        buf32.new: $encoded.ords.map( -> \hi, \lo {@!to-unicode[hi +< 8 + lo]}).grep: {$_};
    }

}
