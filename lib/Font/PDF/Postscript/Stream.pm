class Font::PDF::Postscript::Stream {

    use Native::Packing :Endian;
    use Font::FreeType::Face;
    has UInt @.length;
    has buf8 $.decoded;

    constant Marker = 0x80;
    constant Ascii  = 1;
    constant Binary = 2;

    constant PFA-Header = ('%'.ord, '!'.ord);
    constant PFB-Header = (Marker, Ascii);

    subset PFA-Buf of buf8 where { .[0..1] eqv PFA-Header }
    subset PFB-Buf of buf8 where { .[0..1] eqv PFB-Header }

    class PFB-Section does Native::Packing[Vax] {
        has uint8 $.start-marker;
        has uint8 $.format;
        has uint32 $.length;
    }
    subset PFB-Text-Section of PFB-Section where {
        .start-marker == Marker|-128 && .format == Ascii
    }
    subset PFB-Binary-Section of PFB-Section where {
        .start-marker == Marker|-128 && .format == Binary
    }

    multi submethod TWEAK(PFA-Buf :$buf!) {
        ...
    }

    multi submethod TWEAK(PFB-Buf :$buf!) {
        $!decoded .= new;
        @!length = [];
        my uint8 $marker = 0;
        my uint32 $offset = 0;

        for PFB-Text-Section, PFB-Binary-Section, PFB-Text-Section -> \type {
            $marker++;
            my $header = PFB-Section.unpack($buf, :$offset);
            die "corrupt PFB at marker-$marker, byte offset: $offset"
                unless $header ~~ type;
            $!decoded.append: $buf.subbuf($offset + $header.bytes, $header.length);
            @!length.push: $header.length;
            $offset += $header.bytes + $header.length;
        }
    }

    multi submethod TWEAK(buf8 :$buf!) {
        die "unable to handle postscript buffer. Not in 'PFA' or 'PFB' format";
    }
}
