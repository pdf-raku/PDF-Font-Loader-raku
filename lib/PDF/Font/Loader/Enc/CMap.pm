use v6;
use PDF::COS::Stream;
use PDF::Font::Loader::Enc;

class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    has uint32 @.to-unicode;
    has UInt %!from-unicode;
    # todo handle multiple code-space ranges
    has UInt $.range;
    has UInt %!ligatures{UInt};

    sub valid-codepoint($_) {
        # not an exhuastive check
        $_ <= 0x10FFFF && ! (0xD800 <= $_ <= 0xDFFF);
    }

    method !setup-ligatures {
        # used in some PDF files
        for (
            [0x66,0x66]       => 0xFB00, # ff
            [0x66,0x69]       => 0xFB01, # fi
            [0x66,0x6C]       => 0xFB02, # fl
            [0x66,0x66,0x69]  => 0xFB03, # ffi
            [0x66,0x66,0x6C]  => 0xFB04, # ffl
            [0x66,0x74]       => 0xFB05, # ft
            [0x73,0x74]       => 0xFB06, # st
            # .. +more, see https://en.wikipedia.org/wiki/Orthographic_ligature
        ) {
            my $v = 0;
            for .key {
                $v *= $!range;
                $v += $_;
            }
            %!ligatures{$v} = .value;
        }
        warn :%!ligatures.perl;
    }

    submethod TWEAK(PDF::COS::Stream :$cmap!) {

        for $cmap.decoded.Str.lines {
            if /:s^ \d+ begincodespacerange/ ff /^endcodespacerange/ {
                if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 2 / {
                    my uint ($from, $to) = @<r>.map: { :16(.Str) };
                    # just interested in the sample size
                    given  $to > 0xFF ?? 0xFFFF !! 0xFF {
                        warn "todo: handle variable encoding in CMAPs"
                            if $!range && $!range != $_;
                        $!range = $_;
                    }
                }
            }
            if /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
                if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3 / {
                    my uint ($from, $to, $codepoint) = @<r>.map: { :16(.Str) };
                    for $from .. $to {
                        if valid-codepoint($codepoint) {
                            %!from-unicode{$codepoint} = $_;
                            @!to-unicode[$_] = $codepoint;
                        }
                        else {
                            with %!ligatures{$codepoint} -> $lig {
                                %!from-unicode{$lig} = $_;
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
                        %!from-unicode{$codepoint} = $from;
                        @!to-unicode[$from] = $codepoint;
                    }
                    else {
                        with %!ligatures{$codepoint} -> $lig {
                            %!from-unicode{$lig} = $from;
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
        $!range //= 0xFF;
        self!setup-ligatures();
    }

    method set-encoding($chr-code, $idx) {
        unless @!to-unicode[$idx] ~~ $chr-code {
            @!to-unicode[$idx] = $chr-code;
            %!from-unicode{$chr-code} = $idx;
            $.add-glyph-diff($idx);
        }
    }
    method !decoder {
        $!range > 0xFF
            ?? -> \hi, \lo=0 {@!to-unicode[hi +< 8 + lo]}
            !! -> $_ { @!to-unicode[$_] };
    }

    multi method decode(Str $s, :$str! --> Str) {
        $s.ords.map(self!decoder).grep({$_}).map({.chr}).join;
    }
    multi method decode(Str $s --> buf32) is default {
        # 8 bit Identity decoding
        buf32.new: $s.ords.map(self!decoder).grep: {$_};
    }

    multi method encode(Str $text, :$str! --> Str) {
        self.encode($text).decode: 'latin-1';
    }
    multi method encode(Str $text ) is default {
        # 16 bit Identity-H encoding
        if $!range > 0xFF {
            # let the caller inspect, then repack this
            my uint16 @ = $text.ords.map({ %!from-unicode{$_} }).grep: {$_};
        }
        else {
            buf8.new: $text.ords.map({ %!from-unicode{$_} }).grep: {$_};
        }
    }
}
