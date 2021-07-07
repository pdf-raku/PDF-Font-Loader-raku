unit class PDF::Font::Loader::Enc;

has uint16 @.cid-to-gid-map;
has uint $.first-char;
has uint16 @!widths;
has Bool $.widths-updated is rw;
has Bool $.encoding-updated is rw;
submethod TWEAK(:$widths) {
    @!widths = .map(*.Int) with $widths;
}
multi method first-char { $!first-char }
multi method first-char($cid) {
    unless @!widths {
        $!widths-updated = True;
        $!first-char = $cid;
        @!widths = [0];
    }
    if $!first-char > $cid {
        $!widths-updated = True;
        @!widths.prepend: 0 xx ($!first-char - $cid);
        $!first-char = $cid;
    }
    $!first-char;
}

method last-char { $!first-char + @!widths - 1; }

method widths is rw { @!widths }
method is-wide { False  }
method set-width($cid, $width) {
    die if $cid <= 0;
    my $fc = self.first-char($cid);
    @!widths[$cid - $fc] ||= do {
        $!widths-updated = True;
        $width;
    }
}

