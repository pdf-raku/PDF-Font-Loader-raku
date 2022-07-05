use v6;
use PDF::Font::Loader::Enc :&code-batches;

#| CMap based encoding/decoding
unit class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc;

use PDF::Font::Loader::Enc::Glyphic;
also does PDF::Font::Loader::Enc::Glyphic;

use PDF::IO::Util :&pack;
use PDF::COS::Stream;
use Hash::int;

has uint32 @.to-unicode;
has Int %.charset{Int};
has %!enc-width is Hash::int;
has %!dec-width is Hash::int;
has %.code2cid is Hash::int; # decoding mappings
has %.cid2code is Hash::int; # encoding mappings
has uint8 @cid-width;
has PDF::COS::Stream $.cid-cmap is rw; # Type0 /Encoding CMap
has uint8 $!max-width = 1;
method is-wide { $!max-width >= 2}
my class CodeSpace is export(:CodeSpace) {
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
        '<' ~ @bytes.map({.fmt("%02X")}).join ~ '>';
    }
    method ACCEPTS(CodeSpace:D: Int:D $v is copy) {
        loop (my int $i = $.bytes; --$i >= 0;) {
            return False
                unless @!from[$i] <= $v mod 256 <= @!to[$i];
            $v div= 256;
        }
        $v == 0;
    }
    method width($v) {
        self.ACCEPTS($v) ?? self.bytes !! 0;
    }
    method Str { to-hex(@!from) ~ ' ' ~ to-hex(@!to) }
}
has CodeSpace @!codespaces;
method codespaces is rw {
    Proxy.new(
        FETCH => -> $ { @!codespaces },
        STORE => -> $, @!codespaces {
            $!max-width = @!codespaces>>.bytes.max;
        }
    );
}

sub valid-codepoint($_) {
    # not an exhaustive check
    $_ <= 0x10FFFF && ! (0xD800 <= $_ <= 0xDFFF);
}

constant %Ligatures = %(
    do {
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
    }
);

method enc-width($code is raw) {
   %!enc-width{$code} // do {
        my $bytes = .bytes with @!codespaces.first({.ACCEPTS($code)})
            || die "unable to accomodate code 0x{$code.base(16)}"; # todo: expand, vivify?
        %!enc-width{$code} = $bytes;
    }
}

sub hex-to-codepoint(Str() $x is copy) {
    if $x.chars > 4 {
        # utf16 encoding semantics
        unless  $x.chars %% 4 {
            my \pad = 4  -  $x.chars % 4;
            $x = '0' x pad  ~  $x;
        }

        my int16 @words = $x.comb(/..../).map({ :16($_) });
        my utf16 $buf .= new(@words);
        $buf.decode.ord;
    }
    else {
        :16($x);
    }
}

method load-cmap(Str:D $_) {
    my int $i = 0;
    for .lines {
        if /:s \d+ begincodespacerange/ ff /endcodespacerange/ {
            if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {

                my ($from, $to) = @<r>.map: { [.Str.comb(/../).map({ :16($_)})] };
                my CodeSpace $codespace .= new: :from(@$from), :to(@$to);
                my $bytes := $codespace.bytes;
                $!max-width = $bytes if $bytes > $!max-width;

                @!codespaces[$i++] = $codespace;
            }
        }
        elsif /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
            if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3/ {
                my $srcLo = @<r>[0].Str;
                my $srcHi = @<r>[1].Str;
                my $bytes = $srcLo.chars div 2;
                my uint $lo = :16($srcLo);
                my uint $hi = :16($srcHi);
                my $ord = hex-to-codepoint(@<r>[2]);
                for $lo .. $hi -> $cid {
                    last unless self!add-code($cid, $ord);
                    %!dec-width{$cid} = $bytes;
                    %!enc-width{$ord++} = $bytes;
                }
            }
        }
        elsif /:s^ \d+ beginbfchar/ ff /^endbfchar/ {
            if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                my $srcCode = @<r>[0].Str;
                my $bytes = $srcCode.chars div 2;
                my $code = :16($srcCode);
                my $ord = hex-to-codepoint(@<r>[1]);
                if self!add-code($code, $ord) {
                    %!dec-width{$code} = $bytes;
                    %!enc-width{$ord} = $bytes;
                }
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

submethod TWEAK {
    for self.cmap, self.cid-cmap {
        when PDF::COS::Stream:D {
            my $cmap = .decoded || die "Unable to use {.self.WHAT.raku} decoder";
            self.load-cmap($cmap.Str);
            with .<UseCMap> {
                when PDF::COS::Stream:D {
                    self.load-cmap(.decoded.Str);
                }
                default {
                    warn "todo: /UseCmap /$_";
                }
            }
        }
    }
}

method make-cmap-codespaces {
    @!codespaces>>.Str;
}

method make-encoding-cmap {
    my @content;
    if %!code2cid {
        my @cmap-char;
        my @cmap-range;
        my uint32 @codes = %!code2cid.keys.sort;
        my \n = +@codes;

        loop (my uint16 $i = 0; $i < n; $i++) {
            my uint32 $code = @codes[$i];
            my uint32 $start-code = $code;
            my $start-i = $i;
            my $width = $.enc-width($code);
            my $d = $width * 2;
            my \cid-fmt   := '<%%0%sX>'.sprintf: $d;
            my \char-fmt  := '<%%0%sX> %%d'.sprintf: $d;
            my \range-fmt := cid-fmt ~ ' ' ~ char-fmt;

            while $i < n && @codes[$i+1] == $code+1 && $.enc-width($code+1) == $width {
                $i++; $code++;
            }
            if $start-i == $i {
                @cmap-char.push: char-fmt.sprintf($code, %!code2cid{$code});
            }
            else {
                @cmap-range.push: range-fmt.sprintf($start-code, $code, %!code2cid{$start-code});
            }
        }

        @content.append: code-batches('cidchar', @cmap-char);
        @content.append: code-batches('cidrange', @cmap-range);
    }
    $.make-cmap: $!cid-cmap, @content;
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
            @!to-unicode[$cid] = $lig;
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
method allocate($ord) {
    my $cid := %PreferredEnc{$ord};
    if $cid && !@!to-unicode[$cid] && !%!used-cid{$cid} && !self!skip-cid-block($cid) {
        self.set-encoding($ord, $cid);
    }
    else {
        # sequential allocation
        repeat {
        } while %!used-cid{$!next-cid} || @!to-unicode[++$!next-cid] || self!skip-cid-block($!next-cid) ;
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
method !skip-cid-block($cid is rw) {
    # we can't use a wide encoding who's leading byte sequence conflicts
    # with shorter encodings. Only possible when reusing a CMap with
    # variable encoding.
    my $cid-block = $cid div 256;
    my Bool $skip := False;
    if $cid-block {
        with @!codespaces.first({.ACCEPTS($cid-block)}) {
            $skip := True;
            $cid-block = .to + 1;
        }
        else {
            $skip := self!skip-cid-block($cid-block);
        }
        $cid = $cid-block * 256
            if $skip;
    }
    $skip;
}

method !decode-cid(Int $code) { %!code2cid{$code} || $code }

multi method decode(Str $byte-string, :cids($)!) {
    my uint8 @bytes = $byte-string.ords;

    if $.is-wide {
        my $n := @bytes.elems;
        @bytes.push: 0;
        my uint16 @cids;

        $.protect: {
            loop (my int $i = 0; $i < $n; ) {
                my int $code = 0;
                my int $width = 0;

                repeat {
                    $code = $code * 256 + @bytes[$i++];
                    $width++;
                } until $width >= $!max-width
                || %!dec-width{$code} ~~ $width
                || @!codespaces.first({ .width($code) == $width});

                @cids.push: self!decode-cid($code);
            }
        }

        @cids;
    }
    elsif %!code2cid {
        @.protect: { @bytes.map: {self!decode-cid($_)} }
    }
    else {
        @bytes;
    }
}

multi method decode(Str $s, :ords($)!) {
    @.protect: {self.decode($s, :cids).map({ @!to-unicode[$_] || Empty})};
}

multi method decode(Str $byte-string --> Str) {
    self.decode($byte-string, :ords)».chr.join;
}

multi method encode(Str $text, :cids($)!) {
    @.protect: {$text.ords.map: { %!charset{$_} // self.allocate: $_ }}
}
multi method encode(Str $text --> Str) {
    self!encode-buf($text).decode: 'latin-1';
}
method !encode-buf(Str $text --> Buf:D) {
    my uint32 @cids = self.encode($text, :cids);
    my buf8 $buf;

    if $.is-wide {
        $buf .= new;
        $.protect: {
            for @cids -> $cid {
                my $code = %!cid2code{$cid} || $cid;
                loop (my int $i = self.enc-width($code); --$i >= 0;) {
                    $buf.push: $code div (256 ** $i) mod 256;
                }
            }
        }
    }
    else {
        $buf .= new: @cids;
    }

    $buf;
}

=begin pod

=head3 Description

This method maps to PDF font dictionaries with a `ToUnicode` entry and Type0
(CID) fonts with an `Encoding` entry that reference CMaps.

This class extends the base-class L<PDF::Font::Loader::Enc>, adding the ability
of reading existing CMaps. It also adds the ability the handle variable encoding.

=head3 Methods

This class inherits from L<PDF::Font::Loader::Enc> and has all its method available.

=head3 make-encoding-cmap

Generates a CMap for the /Encoding entry in a PDF Type0 font, which is used to implement
custom variable and wide encodings. This method is typically called from the font object
when an encoding has been added or updated for the encoder.


=head3 Caveats

Most, but not all, CMap encoded fonts have a Unicode mapping. The `has-encoding()`
method should be used to verify this before using the `encode()` or `decode()` methods
on a dictionary loaded CMap encoding.

=end pod
