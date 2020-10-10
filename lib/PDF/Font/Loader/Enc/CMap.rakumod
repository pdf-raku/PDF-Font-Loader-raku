use v6;
use PDF::COS::Stream;
use PDF::Font::Loader::Enc;

class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    has uint32 @.to-unicode;
    has UInt %.charset;
    # todo handle multiple code-space lengths
    has UInt $.bpc;

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
                        my $this-bpc = (@<r>[1].chars + 1) div 2;
                        warn "todo: handle variable encoding in CMAPs (ge, $_)"
                                if $!bpc && $!bpc != $this-bpc;
                        $!bpc = $this-bpc;
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
        $!bpc //= 1;
    }

    method set-encoding($chr-code, $idx) {
        unless @!to-unicode[$idx] ~~ $chr-code {
            @!to-unicode[$idx] = $chr-code;
            %!charset{$chr-code} = $idx;
            $.add-glyph-diff($idx);
        }
    }
    method !decoder {
        $!bpc > 1
            ?? -> \hi, \lo=0 {@!to-unicode[hi +< 8 + lo]}
            !! -> $_ { @!to-unicode[$_] };
    }

    multi method decode(Str $s, :$str! --> Str) {
        $s.ords.map(self!decoder).grep({$_}).map({.chr}).join;
    }
    multi method decode(Str $s --> buf32) is default {
        # Identity decoding
        buf32.new: $s.ords.map(self!decoder).grep: {$_};
    }

    multi method encode(Str $text, :$str! --> Str) {
        self.encode($text).decode: 'latin-1';
    }
    multi method encode(Str $text ) is default {
        if $!bpc > 1 {
            # 2 byte encoding; let the caller inspect, then repack this
            my uint16 @ = $text.ords.map({ %!charset{$_} }).grep: {$_};
        }
        else {
            buf8.new: $text.ords.map({ %!charset{$_} }).grep: {$_};
        }
    }
}
