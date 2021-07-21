use v6;
use PDF::Font::Loader::Enc;

#| CMap based encoding/decoding
class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    use PDF::IO::Util :&pack;
    use Hash::int;

    has uint32 @.to-unicode;
    has Int %.charset{Int};
    has uint8 @!enc-width;
    has %!code2cid is Hash::int; # decoding mappings
    has %!cid2code is Hash::int; # encoding mappings
    has uint8 $!max-width = 1;
    method is-wide { $!max-width >= 2}
    class CodeSpace {
        has byte @.from;
        has byte @.to;
        method bytes { +@!from }
        submethod TWEAK {
            if +@!from != +@!to || @!from.pairs.first({.value > @!to[.key]}) {
                die "bad CMAP Code Range range {@!from.raku} ... {@!to.raku}";
            }
        }
        method iterate-range {
            # Iterate a range such as <AaBbCc> <XxYyZz>.  Each of the hex
            # digits are individually constrained to counting in the ranges
            # Aa..Xx Bb..Yy Cc..Zz (inclusive)

            my class Iteration  does Iterable does Iterator {
                has CodeSpace:D $.codespace is required handles<from to bytes>;
                has byte @!ctr = $!codespace.from.clone.List;
                has Bool $!first = True;

                method pull-one {
                    unless $!first-- {
                        loop (my $i = $.bytes - 1; $i >= 0; $i--) {
                            if @!ctr[$i] < @.to[$i] {
                                # increment
                                @!ctr[$i]++;
                                last;
                            }
                            elsif $i {
                                # carry
                                @!ctr[$i] = @.from[$i];
                            }
                            else {
                                #end
                                return IterationEnd;
                            }
                        }
                    }

                    my $val = 0;
                    for @!ctr {
                        $val *= 0x100;
                        $val += $_;
                    }
                    $val;
                }
                method iterator { self }
            }
            Iteration.new: :codespace(self);
        }
        sub to-hex(@bytes) {
            '<' ~ @bytes.map: {.fmt("%02X")}.join ~ '>';
        }
        method ACCEPTS(CodeSpace:D: Int:D $v is copy) {
            for 0 ..^ $.bytes {
                return False
                    unless @!from[$_] <= $v mod 256 <= @!to[$_];
                $v div= 256;
            }
            $v == 0;
        }
        method Str { to-hex(@!from) ~ ' ' ~ to-hex(@!to) }
    }
    has CodeSpace @!codespaces;

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
        with self.cmap {
            for .decoded.Str.lines {
                if /:s \d+ begincodespacerange/ ff /endcodespacerange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {

                        my ($from, $to) = @<r>.map: { [.Str.comb(/../).map({ :16($_)})] };
                        my CodeSpace $codespace .= new: :from(@$from), :to(@$to);
                        my $bytes := $codespace.bytes;
                        $!max-width = $bytes if $bytes > $!max-width;

                        for $codespace.iterate-range -> $enc {
                            @!enc-width[$enc] = $bytes;
                        }
                        @!codespaces.push: $codespace;
                    }
                }
                elsif /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
                    if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3 / {
                        my uint ($from, $to, $ord) = @<r>.map: { :16(.Str) };
                        for $from .. $to -> $cid {
                            last unless self!add-code($cid, $ord++)
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
                        my Int ($from, $to) = @<r>.map: { :16(.Str) };
                        my Int $cid = $<c>.Int;
                        for $from .. $to -> $code {
                            %!cid2code{$cid} = $code;
                            %!code2cid{$code} = $cid++;
                        }
                    }
                }
                elsif /:s^ \d+ begincidchar/ ff /^endcidchar/ {
                    if /:s '<' $<r>=[<xdigit>+] '>' $<c>=[<digit>+] / {
                        my Int $code = :16($<r>.Str);
                        my Int $cid = $<c>.Int;
                        %!cid2code{$cid}  = $code;
                        %!code2cid{$code} = $cid++;
                    }
                }
            }
        }
    }

    method make-cmap-codespaces {
        @!codespaces>>.Str.join: "\n";
    }

    method !make-cid-ranges {
        my @content;
        if %!code2cid {
            my @cmap-char;
            my @cmap-range;
            my $d = (self.is-wide ?? '4' !! '2');
            my \cid-fmt   := '<%%0%sX>'.sprintf: $d;
            my \char-fmt  := '<%%0%sX> %%d'.sprintf: $d;
            my \range-fmt := cid-fmt ~ ' ' ~ char-fmt;
            my uint32 @codes = %!code2cid.keys.sort;
            my \n = +@codes;

            loop (my uint16 $i = 0; $i <= n; $i++) {
                my uint32 $code = @codes[$i];
                my uint32 $start-code = $code;
                my $start-i = $i;
                while $i < n && @codes[$i+1] == $code+1 {
                    $i++; $code++;
                }
                if $start-i == $i {
                    @cmap-char.push: char-fmt.sprintf(%!code2cid{$i}, $code);
                }
                else {
                    @cmap-range.push: range-fmt.sprintf(%!code2cid{$start-i}, %!code2cid{$i}, $start-code);
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

    method !add-code(Int $cid, Int $ord) {
        my $ok = True;
        if valid-codepoint($ord) {
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

    method set-encoding($ord, $cid) {
        unless @!to-unicode[$cid] ~~ $ord {
            @!to-unicode[$cid] = $ord;
            %!charset{$ord} = $cid;
            # we currently only allocate 2 byte CID encodings
            @!enc-width[$cid] = 1 + $.is-wide.ord;
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
    method !allocate($ord) {
        my $cid := %PreferredEnc{$ord};
        if $cid && !@!to-unicode[$cid] && !%!used-cid{$cid} && !self!ambigous-cid($cid) {
            self.set-encoding($ord, $cid);
        }
        else {
            # sequential allocation
            repeat {
            } while %!used-cid{$!next-cid} || @!to-unicode[++$!next-cid] || self!ambigous-cid($!next-cid) ;
            $cid := $!next-cid;
            if $cid >= 2 ** ($.is-wide ?? 16 !! 8)  {
                has $!out-of-gas //= warn "CID code-range is exhausted";
            }
            else {
                self.set-encoding($ord, $cid);
            }
        }
        $cid;
    }
    method !ambigous-cid($cid) {
        # we can't use a wide encoding who's first byte conflicts with a
        # short encoding. Only possible when reusing a CMap with
        # variable encoding.
        so $.is-wide && $cid >= 256 && @!enc-width[$cid div 256] == 1;
    }
    method !decode-cid(Int $code) { %!code2cid{$code} || $code }
    method !encode-cid(Int $cid)  { %!cid2code{$cid}  || $cid }

    multi method decode(Str $byte-string, :cids($)!) {
        my uint8 @bytes = $byte-string.ords;

        if $.is-wide {
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
        elsif %!code2cid {
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

        if $.is-wide {
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

=begin pod

=head3 Description

This method maps to PDF font dictionaries with a `ToUnicode` entry that references
a CMap.

=head3 Caveats

Most, but not all, CMap encoded fonts have a Unicode mapping. The `has-encoding()`
method should be used to verify this before using the `encode()` or `decode()` methods
on a dictionary loaded CMap encoding.

=head2 Bugs / Limitations

Currently, this class:

=item can read, but not write variable width CMap encodings.

=item only handles one or two byte encodings

=end pod
