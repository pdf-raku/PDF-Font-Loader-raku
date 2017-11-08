class PDF::Font::TrueType {
    use PDF::DAO;
    use PDF::IO::Blob;
    use PDF::Content::Font::Enc::Type1;
    use Font::FreeType;
    use Font::FreeType::Face;

    has Font::FreeType::Face $.face;
    has PDF::Content::Font::Enc::Type1 $!encoder handles <decode enc>;
    has Blob $.font-stream is required;
    use PDF::Content::Font;
    has PDF::Content::Font $!dict;
    has Int $!first-char;
    has Int $!last-char;
    has int16 @!widths;

    submethod TWEAK(:$enc = 'win') {
        $!encoder = PDF::Content::Font::Enc::Type1.new: :$enc;
        @!widths[255] = 0;
    }

    method encode(Str $text, :$str) {
        my buf8 $encoded = $!encoder.encode($text);

        given $.to-dict {
            my $min = $encoded.min;
            my $max = $encoded.max;

            my $to-unicode := $!encoder.to-unicode;
            for $encoded.list {
                @!widths[$_] ||= $.stringwidth($to-unicode[$_].chr).round;
            }

            if !$!first-char || $min < $!first-char {
                .<FirstChar> = $!first-char = $min;
            }

            if !$!last-char || $max > $!last-char {
                .<LastChar> = $!last-char = $max;
            }

            .<Widths> = @!widths[$!first-char .. $!last-char];
        }
        $str
            ?? $encoded.decode('latin-1')
            !! $encoded;
    }

    method !font-descriptor {
        my $Ascent = $!face.ascender;
        my $Descent = $!face.descender;
        my $FontName = PDF::DAO.coerce: :name($!face.postscript-name);
        my $FontFamily = $!face.family-name;
        my $FontBBox = $!face.bounding-box.Array;
        my $decoded = PDF::IO::Blob.new: $!font-stream;
        my $FontFile2 = PDF::DAO.coerce: :stream{ 
            :$decoded,
            :dict{
                :Length1($!font-stream.bytes),
                :Filter( :name<FlateDecode> ),
            },
        };

        my $dict = {
            :Type( :name<FontDescriptor> ),
            :$FontName, :$FontFamily, :$Ascent, :$Descent, :$FontBBox, :$FontFile2,
        };
    }

    method to-dict {
        $!dict //= do {
            my %enc-name = :win<WinAnsiEncoding>, :mac<MacRomanEncoding>;
            my $FontDescriptor = self!font-descriptor;
            my $BaseFont = $FontDescriptor<FontName>;
            my $dict = { :Type( :name<Font> ), :Subtype( :name<TrueType> ),
                         :$BaseFont,
                         :$FontDescriptor,
            };

            with %enc-name{self.enc} -> $name {
                $dict<Encoding> = :$name;
            }

            PDF::Content::Font.make-font(
                PDF::DAO::Dict.coerce($dict),
                self);
        }
    }

    multi method stringwidth(Str $str is copy, $pointsize = 1000, Bool :$kern=False) {
        $str = 'i' if $str eq ' '; # hack
        $!face.set-char-size($pointsize, $pointsize, 72, 72);
        my $vec = $!face.measure-text( $str, :$kern);
        $vec.x;
    }

}
