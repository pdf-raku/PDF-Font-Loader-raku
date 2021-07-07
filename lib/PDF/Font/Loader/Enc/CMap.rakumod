use v6;
use PDF::COS::Stream;
use PDF::Font::Loader::Enc;

class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    use PDF::IO::Util :&pack;

    has uint32 @.to-unicode;
    has Int %.charset{Int};
    has uint8 @!enc-width;
    has Bool $.is-wide = self.face.num-glyphs > 255;

    sub valid-codepoint($_) {
        # not an exhaustive check
        $_ <= 0x10FFFF && ! (0xD800 <= $_ <= 0xDFFF);
    }

    constant %Ligatures = %(do {
        (
            [0x66,0x66]       => 0xFB00, # ff
            [0x66,0x69]       => 0xFB01, # fi
            [0x66,0x6C]       => 0xFB02, # fl
            [0x66,0x66,0x69]  => 0xFB03, # ffi
            [0x66,0x66,0x6C]  => 0xFB04, # ffl
            [0x66,0x74]       => 0xFB05, # ft
            [0x73,0x74]       => 0xFB06, # st
            # .. + more, see https://en.wikipedia.org/wiki/Orthographic_ligature
        ).map: {
            my $k = 0;
            for .key {
                $k +<= 16;
                $k += $_;
            }
            $k => .value;
        }
    });

    submethod TWEAK(PDF::COS::Stream :$cmap) {
        with $cmap {
            for .decoded.Str.lines {
                if /:s \d+ begincodespacerange/ ff /endcodespacerange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                        my $bytes = (@<r>[1].chars + 1) div 2;
                        $!is-wide ||= $bytes == 2;
                        if $bytes > 2 {
                            has $!nyi //= "CMAP encodings > 2 bytes is NYI";
                            $bytes = 2;
                        }

                        my ($low-enc, $high-enc) = @<r>.map: { :16(.Str) };
                        @!enc-width[$high-enc] = 0; # allocate
                        for $low-enc .. $high-enc -> $enc {
                            @!enc-width[$enc] = $bytes;
                        }
                    }
                }
                if /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3 / {
                        my uint ($from, $to, $codepoint) = @<r>.map: { :16(.Str) };
                        for $from .. $to {
                            if valid-codepoint($codepoint) {
                                %!charset{$codepoint} = $_;
                                @!to-unicode[$_] = $codepoint;
                            }
                            else {
                                with %Ligatures{$codepoint} -> $lig {
                                    %!charset{$lig} = $_;
                                    @!to-unicode[$_] = $lig;
                                }
                                elsif 0xFFFF < $codepoint < 0xFFFFFFFF {
                                    warn sprintf("skipping possible unmapped ligature: U+%X...", $codepoint);
                                }
                                else {
                                    warn sprintf("skipping invalid codepoint(s) in CMAP: U+%X...", $codepoint);
                                    last;
                                }
                            }
                            $codepoint++;
                        }
                    }
                }
                if /:s^ \d+ beginbfchar/ ff /^endbfchar/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                        my uint ($from, $codepoint) = @<r>.map: { :16(.Str) };
                        if valid-codepoint($codepoint) {
                            %!charset{$codepoint} = $from;
                            @!to-unicode[$from] = $codepoint;
                        }
                        else {
                            with %Ligatures{$codepoint} -> $lig {
                                %!charset{$lig} = $from;
                                @!to-unicode[$from] = $lig;
                            }
                            elsif 0xFFFF < $codepoint < 0xFFFFFFFF {
                                warn sprintf("skipping possible unmapped ligature: U+%X...", $codepoint);
                            }
                            else {
                                warn sprintf("skipping invalid codepoint in CMAP: U+%X", $codepoint);
                            }
                        }
                    }
                }
            }
        }
    }

    method set-encoding($chr-code, $cid) {
        unless @!to-unicode[$cid] ~~ $chr-code {
            @!to-unicode[$cid] = $chr-code;
            %!charset{$chr-code} = $cid;
            # we currently only allocate 2 byte CID encodings
            @!enc-width[$cid] = 1 + $!is-wide.ord;
            $.add-glyph-diff($cid);
        }
        $cid;
    }

    my constant %PreferredEnc = do {
        use PDF::Content::Font::Encodings :$win-encoding;
        my Int %win{Int};
        %win{.value} = .key
            for $win-encoding.pairs;
        %win;
    }
    has UInt $!next-cid = 0;
    has %!used-cid;
    method use-cid($_) { %!used-cid{$_}++ }
    method !allocate($chr-code) {
        my $cid := %PreferredEnc{$chr-code};
        if $cid && !@!to-unicode[$cid] && !%!used-cid{$cid} && !self!ambigous-cid($cid) {
            self.set-encoding($chr-code, $cid);
        }
        else {
            # sequential allocation
            repeat {
            } while %!used-cid{$!next-cid} || @!to-unicode[++$!next-cid] || self!ambigous-cid($!next-cid) ;
            $cid := $!next-cid;
            if $cid >= 2 ** ($!is-wide ?? 16 !! 8)  {
                has $!out-of-gas //= warn "CID code-range is exhausted";
            }
            else {
                self.set-encoding($chr-code, $cid);
            }
        }
        $cid;
    }
    method !ambigous-cid($cid) {
        # we can't use a wide encoding who's first byte conflicts with a
        # short encoding. Only possible when reusing a CMap with
        # variable encoding.
        so $!is-wide && $cid >= 256 && @!enc-width[$cid div 256] == 1;
    }

    multi method decode(Str $byte-string, :cids($)!) {
        my uint8 @bytes = $byte-string.ords;

        if $!is-wide {
            my $n := @bytes.elems;
            @bytes.push: 0;
            my uint16 @cids;

            loop (my int $i = 0; $i < $n; ) {
                my $cid = @bytes[$i++];
                # look ahead to see if this is a two byte encoding
                my $cid2 = $cid * 256 + @bytes[$i];
                if @!enc-width[$cid2] == 2 {
                    $cid := $cid2;
                    $i++;
                }
                @cids.push: $cid;
            }
            @cids;
        }
        else {
            @bytes;
        }
    }

    multi method decode(Str $s, :ords($)!) {
        self.decode($s, :cids).map({ @!to-unicode[$_] }).grep: *.so;
    }

    multi method decode(Str $text --> Str) {
        self.decode($text, :ords)».chr.join;
    }

    multi method encode(Str $text, :cids($)!) {
        $text.ords.map: { %!charset{$_} // self!allocate: $_ }
    }
    multi method encode(Str $text --> Str) {
        self!encode-buf($text).decode: 'latin-1';
    }
    method !encode-buf(Str $text --> Buf:D) {
        my uint32 @cids = self.encode($text, :cids);
        my buf8 $buf;

        if $!is-wide {
            $buf .= new;
            for @cids -> $cid {
                if @!enc-width[$cid] == 2 {
                    $buf.push: $cid div 256;
                    $buf.push: $cid mod 256;
                }
                else {
                    $buf.push: $cid;
                }
            }
        }
        else {
            $buf .= new: @cids;
        }

        $buf;
    }
}
