class PDF::Font {

    use Font::FreeType;
    use Font::FreeType::Face;
    use PDF::Font::TrueType;
    subset TrueTypish of Font::FreeType::Face where .font-format eq 'TrueType'|'CFF';

    multi method load-font(Str $font-file!, |c) is default {
        my $free-type = Font::FreeType.new;
        my $font-stream = $font-file.IO.open(:r, :bin).slurp: :bin;
        my $face = $free-type.face($font-stream);
        self.load-font($face, :$font-stream, |c);
    }

    multi method load-font(TrueTypish $face, |c) {
        PDF::Font::TrueType.new( :$face, |c);
    }

    multi method load-font(Font::FreeType::Face $face, |c) {
        die "unsupported font format: {$face.font-format}";
    }
}
