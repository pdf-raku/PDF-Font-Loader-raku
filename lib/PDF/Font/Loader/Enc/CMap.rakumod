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
    has uint16 @!cid-dec-map; # decoding mappings
    has uint16 @!cid-enc-map; # encoding mappings
    has Bool $.is-wide = self.face.num-glyphs > 255;
    my enum NYI (
        :XWide("encodings > 2 bytes"),
        :VarEnc("variable encoding"),
        :CIDMap("CID mappings"),
    );
    has NYI $!nyi;

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

    submethod TWEAK {
        my uint @w;
        with self.cmap {
            for .decoded.Str.lines {
                if /:s \d+ begincodespacerange/ ff /endcodespacerange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                        my $bytes = (@<r>[1].chars + 1) div 2;
                        $!is-wide ||= $bytes == 2;
                        @w[$bytes]++;
                        if $bytes > 2 {
                            $!nyi //= NYI::XWide;
                            $bytes = 2;
                        }

                        my ($low-enc, $high-enc) = @<r>.map: { :16(.Str) };

                        for $low-enc .. $high-enc -> $enc {
                            @!enc-width[$enc] = $bytes;
                        }
                    }
                }
                elsif /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3 / {
                        my uint ($from, $to, $ord) = @<r>.map: { :16(.Str) };
                        for $from .. $to {
                            last unless self!add-code($_, $ord++)
                        }
                    }
                }
                elsif /:s^ \d+ beginbfchar/ ff /^endbfchar/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                        my uint ($cid, $ord) = @<r>.map: { :16(.Str) };
                        self!add-code($cid, $ord);
                    }
                }
                elsif /:s^ \d+ begincidrange/ ff /^endcidrange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 $<c>=[<digit>+] / {
                        my uint ($from, $to) = @<r>.map: { :16(.Str) };
                        my $cid = $<c>.Int;
                        for $from .. $to {
                            @!cid-enc-map[$cid] = $_;
                            @!cid-dec-map[$_] = $cid++;
                        }
                    }
                }
                elsif /:s^ \d+ begincidchar/ ff /^endcidchar/ {
                    if /:s '<' $<r>=[<xdigit>+] '>' $<c>=[<digit>+] / {
                        my uint $code = :16($<r>.Str);
                        my $cid = $<c>.Int;
                        @!cid-enc-map[$cid]  = $code;
                        @!cid-dec-map[$code] = $cid++;
                    }
                }
            }
        }

        if $!nyi ~~ NYI::XWide {
            warn "NYI reading of CMAPs with encodings > 2 bytes";
        }
        elsif @w[1] && @w[2] {
            $!nyi //= NYI::VarEnc
        }

    }

    method !make-cid-ranges {
        my @content;
        if @!cid-dec-map {
            my @cmap-char;
            my @cmap-range;
            my $d = (self.is-wide ?? '4' !! '2');
            my \cid-fmt   := '<%%0%sX>'.sprintf: $d;
            my \char-fmt  := '<%%0%sX> %%d'.sprintf: $d;
            my \range-fmt := cid-fmt ~ ' ' ~ char-fmt;
            my \n = +@!cid-dec-map;

            loop (my uint16 $idx = 0; $idx <= n; $idx++) {
                my uint32 $code = @!cid-dec-map[$idx]
                    || next;
                my uint16 $start-idx = $idx;
                my uint32 $start-code = $code;
                while $idx < n && @!cid-dec-map[$idx + 1] == $code+1 {
                    $idx++; $code++;
                }
                if $start-idx == $idx {
                    @cmap-char.push: char-fmt.sprintf($idx, $code);
                }
                else {
                    @cmap-range.push: range-fmt.sprintf($start-idx, $idx, $start-code);
                }
            }

            if @cmap-char {
                @content.push: "{+@cmap-char} begincidchar";
                @content.append: @cmap-char;
                @content.push: 'endcidchar';
            }

            if @cmap-range {
                @content.push: "{+@cmap-range} begincidrange";
                @content.append: @cmap-range;
                @content.push: 'endcidrange';
            }
        }

        @content.unshift: '' if @content;
        @content.join: "\n";
    }

    method make-cmap-content {
        callsame() ~ self!make-cid-ranges();
    }

    method make-cmake {
        with $!nyi {
            # We can yet rewrite this particular CMAP
            warn "NYI writing of CMaps with $_";
            self.cmap.decoded;
        }
        else {
            callsame();
        }
    }

    method !add-code($cid, $ord) {
        my $ok = True;
        if @!cid-enc-map && ! @!cid-enc-map[$cid] {
            $!nyi //= NYI::CIDMap;
        }
        elsif valid-codepoint($ord) {
            %!charset{$ord} = $cid;
            @!to-unicode[$cid] = $ord;
        }
        else {
            with %Ligatures{$ord} -> $lig {
                %!charset{$lig} = $cid;
                @!to-unicode[$_] = $lig;
            }
            elsif 0xFFFF < $ord < 0xFFFFFFFF {
                warn sprintf("skipping possible unmapped ligature: U+%X...", $ord);
            }
            else {
                warn sprintf("skipping invalid ord(s) in CMAP: U+%X...", $ord);
                $ok = False;
            }
        }
        $ok;
    }

    method set-encoding($chr-code, $cid) {
        unless @!to-unicode[$cid] ~~ $chr-code {
            @!to-unicode[$cid] = $chr-code;
            %!charset{$chr-code} = $cid;
            # we currently only allocate 2 byte CID encodings
            @!enc-width[$cid] = 1 + $!is-wide.ord;
            $.add-glyph-diff($cid);
            $.encoding-updated = True;
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
    method !decode-cid($byte is raw) { @!cid-dec-map[$byte] || $byte }
    method !encode-cid($byte is raw) { @!cid-enc-map[$byte] || $byte }

    multi method decode(Str $byte-string, :cids($)!) {
        my uint8 @bytes = $byte-string.ords;

        if $!is-wide {
            my $n := @bytes.elems;
            @bytes.push: 0;
            my uint16 @cids;

            loop (my int $i = 0; $i < $n; ) {
                my $sample := @bytes[$i++];
                my $sample2 := $sample * 256 + @bytes[$i];

                if @!enc-width[$sample2] == 2 {
                    $sample := $sample2;
                    $i++;
                }

                @cids.push: self!decode-cid($sample);
            }
            @cids;
        }
        elsif @!cid-dec-map {
            @bytes.map: {self!decode-cid($_)}
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
        $text.ords.map: { self!encode-cid: %!charset{$_} // self!allocate: $_ }
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
