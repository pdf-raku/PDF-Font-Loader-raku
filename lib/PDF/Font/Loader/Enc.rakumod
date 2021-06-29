class PDF::Font::Loader::Enc {
    has uint16 @.cid-to-gid-map;

    method bytes-per-cid { 1 }

    method cids($byte-str) {
        self.bytes-per-cid >= 2
            ?? $byte-str.ords.map: -> \hi, \lo { hi +< 8 + lo }
            !! $byte-str.ords;
    }
}
