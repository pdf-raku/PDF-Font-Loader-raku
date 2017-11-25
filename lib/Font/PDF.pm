class Font::PDF {

    use Font::FreeType;
    use Font::FreeType::Face;
    use Font::PDF::FreeType;
    use Font::PDF::Type1;
    subset TrueTypish of Font::FreeType::Face where .font-format eq 'TrueType'|'CFF';
    subset Postscripty of Font::FreeType::Face where .font-format eq 'Type 1';

    multi method load-font(Str $font-file!, |c) is default {
        my $free-type = Font::FreeType.new;
        my $font-stream = $font-file.IO.open(:r, :bin).slurp: :bin;
        my $face = $free-type.face($font-stream);
        self.load-font($face, :$font-stream, |c);
    }

    multi method load-font(TrueTypish $face, |c) {
        Font::PDF::FreeType.new( :$face, |c);
    }

    multi method load-font(Postscripty $face, |c) {
        Font::PDF::Type1.new( :$face, |c);
    }

    multi method load-font(Font::FreeType::Face $face, |c) {
        die "unsupported font format: {$face.font-format}";
    }
}
