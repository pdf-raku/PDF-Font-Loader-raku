use v6;
use PDF::COS::Stream;
use PDF::Font::Loader::Enc;

class PDF::Font::Loader::Enc::CMap
    is PDF::Font::Loader::Enc {
    use PDF::Font::Loader::Enc::Glyphic;
    also does PDF::Font::Loader::Enc::Glyphic;

    has uint32 @.to-unicode;
    has UInt %!from-unicode;
    has Str $.enc;

    sub valid-codepoint($_) {
        # not an exhuastive check
        $_ <= 0x10FFFF && ! (0xD800 <= $_ <= 0xDFFF);
    }

    submethod TWEAK(PDF::COS::Stream :$cmap!) {

        for $cmap.decoded.Str.lines {
            if /:s^ \d+ beginbfrange/ ff /^endbfrange/ {
                if /:s [ '<' $<r>=[<xdigit>+] '>' ] ** 3 / {
                    my uint ($from, $to, $codepoint) = @<r>.map: { :16(.Str) };
                    for $from .. $to {
                        if valid-codepoint($codepoint) {
                            %!from-unicode{$codepoint} = $_;
                            @!to-unicode[$_] = $codepoint++;
                        }
                        else {
                            warn sprintf("skipping invalid codepoint(s) in CMAP: U+%X...", $codepoint);
                            last;
                        }
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
                        warn sprintf("skipping invalid codepoint in CMAP: U+%X", $codepoint);
                    }
                }
            }
        }
    }

    method set-encoding($chr-code, $idx) {
        unless @!to-unicode[$idx] ~~ $chr-code {
            @!to-unicode[$idx] = $chr-code;
            %!from-unicode{$chr-code} = $idx;
            $.add-glyph-diff($idx);
        }
    }
    multi method decode(Str $s, :$str! --> Str) {
        $s.ords.map({@!to-unicode[$_]}).grep({$_}).map({.chr}).join;
    }
    multi method decode(Str $s --> buf32) {
        buf32.new: $s.ords.map({@!to-unicode[$_]}).grep: {$_};
    }

    multi method encode(Str $text, :$str! --> Str) {
        self.encode($text).decode: 'latin-1';
    }
    multi method encode(Str $text where $!enc ~~ 'identity-h') {
        # 16 bit Identity-H encoding
        my uint16 @ = $text.ords.map({ %!from-unicode{$_} }).grep: {$_};
    }
    multi method encode(Str $text where $!enc ~~ 'identity' --> buf8) {
        # 8 bit Identity encoding
        buf8.new: $text.ords.map({ %!from-unicode{$_} }).grep: {$_};
    }
    multi method encode($) { fail "unsupported CMAP encoding: $!enc"  }
}
