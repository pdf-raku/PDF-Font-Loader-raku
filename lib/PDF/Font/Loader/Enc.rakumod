class PDF::Font::Loader::Enc {

    method bytes-per-cid { 1 }

    method cids($byte-str) {
        self.bytes-per-cid >= 2
            ?? $byte-str.ords.map: -> \hi, \lo { hi +< 8 + lo }
            !! $byte-str.ords;
    }

    method cid-to-gid($cid) { $cid }
}
