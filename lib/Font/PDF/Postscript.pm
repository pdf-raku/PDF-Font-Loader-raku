class Font::PDF::Postscript {

    use Native::Packing;
    use Font::FreeType::Face;

    constant Marker = 0x80;
    constant Ascii  = 1;
    constant Binary = 2;

    constant PFB-Header (Marker, Ascii);
    constant PFA-Header ('%'.ord, '!'.ord);

    subset PFA-Buf of buf8 where { .[0..1] eqv PFA-Header }
    subset PFB-buf of buf8 where { .[0..1] eqv PFB-Header }

    class PFB-Section does Native::Packing[Vax] {
        has byte $.start-marker;
        has byte $.format;
        has uint32 $.length;
    }
    subset PFB-Text-Section of PFB-Section where {
        .start-marker == Marker && .format == Ascii
    }
    subset PFB-Binary-Section of PFB-Section where {
        .start-marker == Marker && .format == Binary
    }

}
