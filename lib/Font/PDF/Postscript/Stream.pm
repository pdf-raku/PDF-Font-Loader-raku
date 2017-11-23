class Font::PDF::Postscript::Stream {

    use Native::Packing :Endian;
    use Font::FreeType::Face;

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
        (my uint8 $ = .start-marker) == Marker && .format == Ascii
    }
    subset PFB-Binary-Section of PFB-Section where {
        (my uint8 $ =.start-marker) == Marker && .format == Binary
    }

    multi method unpack(PFA-Buf $buf --> buf8) {
        ...
    }

    multi method unpack(PFB-Buf $buf --> buf8) {
        my buf8 $packed .= new;
        my uint8 $marker = 0;
        my uint32 $offset = 0;

        for PFB-Text-Section, PFB-Binary-Section, PFB-Text-Section -> \type {
            $marker++;
            my $header = PFB-Section.unpack($buf, :$offset);
            die "corrupt PFB at marker-$marker, byte offset: $offset"
                unless $header ~~ type;
            $packed.append: $buf.subbuf($offset + $header.bytes, $header.length);
            $offset += $header.bytes + $header.length;
        }
        $packed;
    }

    multi method to-stream(buf8 $buf) {
        die "unable to handle postscript buffer. Not in 'PFA' or 'PFB' format";
    }
}
