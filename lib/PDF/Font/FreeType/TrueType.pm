class PDF::Font::FreeType::TrueType {
    use PDF::DAO;
    use PDF::IO::Blob;
    use PDF::Content::Font::Enc::Type1;
    use Font::FreeType;
    use Font::FreeType::Face;

    has Font::FreeType::Face $.face;
    has PDF::Content::Font::Enc::Type1 $!encoder handles <encode decode enc>;
    has Blob $.font-stream is required;

    submethod TWEAK(:$enc = 'win') {
        $!encoder = PDF::Content::Font::Enc::Type1.new: :$enc;
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

        PDF::DAO.coerce: :$dict;
    }

}
