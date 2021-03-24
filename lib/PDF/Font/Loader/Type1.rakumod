use PDF::Font::Loader::FreeType;
class PDF::Font::Loader::Type1 is PDF::Font::Loader::FreeType {

    use PDF::Font::Loader::Type1::Stream;
    use PDF::COS::Stream;
    use PDF::IO::Blob;

    method font-file {
        my PDF::Font::Loader::Type1::Stream $stream .= new: :buf(self.font-stream);
        my PDF::IO::Blob $decoded .= COERCE: $stream.decoded;
        my $Length1 = $stream.length[0];
        my $Length2 = $stream.length[1];
        my $Length3 = $stream.length[2];
        my PDF::COS::Stream $font-file .= COERCE: :stream{
            :$decoded,
            :dict{
                :$Length1, :$Length2, :$Length3,
            },
        };
    }

}
