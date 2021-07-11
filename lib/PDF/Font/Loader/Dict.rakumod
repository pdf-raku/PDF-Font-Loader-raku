#| Loads a font from a PDF font dictionary (experimental)
class PDF::Font::Loader::Dict {
    use PDF::Content::Font::CoreFont;
    use PDF::COS::Stream;
    use PDF::IO::Util :pack;
    my subset FontDict of Hash where .<Type> ~~ 'Font';

    sub base-font($dict) {
        $dict<Subtype> ~~ 'Type0'
            ?? $dict<DescendantFonts>[0]
            !! $dict;
    }
    sub font-descriptor(FontDict $dict is copy) is rw {
        base-font($dict)<FontDescriptor>;
    }

    sub base-enc($_, :$dict!) {
        when 'CMap'              { 'cmap' }
        when 'Identity-H'        { 'identity-h' }
        when 'Identity-V'        { 'identity-v' }
        when 'WinAnsiEncoding'   { 'win' }
        when 'MacRomanEncoding'  { 'mac' }
        when 'MacExpertEncoding' { 'mac-extra' }
        when 'StandardEncoding'  { 'std' }
        default {
            warn "unimplemented font encoding: $_"
                with $_;
            Nil;
        }
    }

    method is-core-font($?: FontDict :$dict! ) is export(:is-core-font) {
        $dict<Subtype> ~~ 'Type1'
        && ! font-descriptor($dict).defined
    }

    method is-embedded-font( FontDict :$dict! ) {
        do with font-descriptor($dict) {
            (.<FontFile>:exists) || (.<FontFile2>:exists) || (.<FontFile3>:exists)
        }
    }

    # Decode widths from a /FontDescriptor /W array
    sub decode-widths($W) {
        my $first-char = $W[0];
        my uint16 @widths;
        my int $i = 0;
        my int $n = $W.elems;

        while $i < $n {
            my $code = $W[$i++];
            if $code < $first-char {
                # Allow codes to be in any sequence
                @widths.prepend: 0 xx ($first-char - $code);
                $first-char = $code;
            }
            given $W[$i++] {
                when Array {
                    my $a := $_;
                    # format: code [W1 W2 ...]
                    @widths[$code + $_ - $first-char] = $a[$_]
                        for 0 ..^ $a.elems;
                }
                when Numeric {
                    # format: code code2 W
                    my $code2 := $_;
                    my $width := $W[$i++];
                    @widths[$_ - $first-char] = $width
                       for $code .. $code2;
                }
                default {
                    warn "unexpected {.raku} in /W (widths) array";
                }
            }
        }

        my $last-char = $first-char + @widths - 1;
        ( $first-char, $last-char, @widths );
    }

    method load-font-opts($?: FontDict :$dict! is copy, Bool :$embed = False, |c) is export(:load-font-opts) {
        my %opt = :!subset, :$embed, :$dict;
        my %encoder;

        with $dict<Encoding> {
            %opt<enc> = do {
                when PDF::COS::Stream {
                    # assume CMAP. See PDF-32000 Table 121
                    # – Entries in a Type 0 font dictionary
                    %encoder<cmap> = $_;
                    'cmap';
                }
                when Hash {
                    %opt<differences> = $_ with .<Differences>;
                    base-enc(.<BaseEncoding>, :$dict);
                }
                default { base-enc($_, :$dict); }
            }
        }

        with $dict<ToUnicode> -> PDF::COS::Stream $cmap {
            
            %opt<enc> //= 'cmap';
            %encoder<cmap> //= $cmap;
        }

        if $dict<Subtype> ~~ 'Type0' {
            # CiD Font
            given base-font($dict) {
                with .<W> -> $W {
                    %encoder<first-char last-char widths> = decode-widths($W);
                }
                with .<CIDToGIDMap> {
                    when 'Identity' {
                    }
                    when PDF::COS::Stream {
                        my $decoded = .decoded;
                        $decoded .= encode('latin-1') if $decoded ~~ Str;
                        my uint16 @gids = unpack($decoded, 16);
                        %opt<cid-to-gid-map> = @gids;
                    }
                    default {
                        # probably a named CMAP
                        warn "unable to handle /CIDToGIDMap $_ for this font";
                    }
                }
            }
        }
        else {
            %encoder<first-char> = $_ with $dict<FirstChar>;
            %encoder<last-char>  = $_ with $dict<LastChar>;
            %encoder<widths>     = $_ with $dict<Widths>;
        }
        %opt<encoder> = %encoder;

        enum (:SymbolicFlag(1 +< 5), :ItalicFlag(1 +< 6));

        %opt<font-descriptor> = font-descriptor($dict);

        with %opt<font-descriptor> {
            %opt<font-name> = $_ with .<FontName>;

            %opt<width> = .lc with .<FontStretch>;
            %opt<weight> = $_ with .<FontWeight>;
            %opt<slant> = 'italic'
                if .<ItalicAngle> // (.<Flags> +& ItalicFlag);
            %opt<family> = .<FontFamily> // do {
                with $dict<BaseFont> {
                    # remove any subset prefix
                    .subst(/^<[A..Z]>**6'+'/,'');
                }
                else {
                    'courier';
                }
            }

            with .<FontFile> // .<FontFile2> // .<FontFile3> {
                %opt<font-buf> = do given .decoded {
                    $_ ~~ Blob ?? $_ !! .encode("latin-1")
                }
            }

            # See [PDF 32000 Table 114 - Entries in an encoding dictionary]
            %opt<enc> //= do {
                my $symbolic := ?((.<Flags>//0) +& SymbolicFlag);
                # in-case a Type 1 font has been marked as symbolic
                my $type1 = True with .<FontFile> // %opt<differences>;
                $type1 //= .<Subtype> ~~ 'Type1C'
                    with .<FontFile3>;

                $embed && $symbolic && !$type1
                    ?? 'identity'
                    !! 'std';
            }
        }
        else {
            # no font descriptor. assume core font
            my $font-name = $dict<BaseFont> // 'courier';
            my $family = $font-name;
            %opt<weight> = 'bold' if $family ~~ s/:i ['-'|',']? bold //;
            %opt<slant> = $0.lc if $family ~~ s/:i ['-'|',']? (italic|oblique) //;
            %opt ,= :$font-name;
            %opt ,= :$family;
            %opt<enc> //= do given $family {
                when /:i ^[ZapfDingbats|WebDings]/ {'zapf'}
                when /:i ^[Symbol]/ {'sym'}
                default {'std'}
            }
        }

        %opt;
    }

}
