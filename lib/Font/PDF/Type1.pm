use Font::PDF::FreeType;
class Font::PDF::Type1 is Font::PDF::FreeType {

    use Font::PDF::Type1::Stream;
    use PDF::DAO;
    use PDF::IO::Blob;

    method font-file {
        my Font::PDF::Type1::Stream $stream .= new: :buf(self.font-stream);
        my $decoded = PDF::IO::Blob.new: $stream.decoded;
        my $Length1 = $stream.length[0];
        my $Length2 = $stream.length[1];
        my $Length3 = $stream.length[2];
        my $font-file = PDF::DAO.coerce: :stream{
            :$decoded,
            :dict{
                :$Length1, :$Length2, :$Length3,
            },
        };
    }

}