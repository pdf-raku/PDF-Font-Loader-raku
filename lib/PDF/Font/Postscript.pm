class PDF::Font::Postscript {

    use Native::Packing;
    use Font::FreeType::Face;

    constant Marker = 0x80;
    constant Ascii  = 1;
    constant Binary = 2;

    subset PFA-Buf of buf8 where { .[0] == '%'.ord && .[1] == '!'.ord }
    subset PFB-Buf of buf8 where { .[0] == Marker  && .[1] == Ascii }

    class PFB-Section does Native::Packing[Vax] {
        has byte $.start-marker;
        has byte $.format;
        has uint32 $.length;
    }
    subset PFB-Section-Text of PFB-Section where {
        .start-marker == Marker && .format == Ascii
    }
    subset PFB-Section-Binary of PFB-Section where {
        .start-marker == Marker && .format == Binary
    }

}
