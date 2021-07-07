class PDF::Font::Loader::Enc {
    has uint16 @.cid-to-gid-map;
    method is-wide { False  }

}
