class PDF::Font::Enc::Identity-H {

    use Font::FreeType::Face;
    use PDF::DAO;

    has Font::FreeType::Face $.face is required;
    has uint32 @.to-unicode;

    multi method encode(Str $text, :$str! --> Str) {
        my $hex-string = self.encode($text).decode: 'latin-1';
        PDF::DAO.coerce: :$hex-string;
    }
    multi method encode(Str $text --> buf8) is default {
        my uint8 @codes;
        my $face-struct = $!face.struct;
        for $text.ords {
            my uint $index = $face-struct.FT_Get_Char_Index($_);
            @!to-unicode[$index] ||= $_;
            @codes.push: $index div 256;
            @codes.push: $index mod 256;
        }
        buf8.new: @codes;
    }

}
