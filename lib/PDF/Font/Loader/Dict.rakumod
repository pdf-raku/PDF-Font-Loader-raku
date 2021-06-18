
#| Loads a font from a PDF font dictionary (experimental)
class PDF::Font::Loader::Dict {
    my subset FontDict of Hash where .<Type> ~~ 'Font';

    method !base-enc($_, :$dict!) {
        when 'Identity-H'        {'identity-h' }
        when 'Identity-V'        {'identity-v' }
        when 'WinAnsiEncoding'   { 'win' }
        when 'MacRomanEncoding'  { 'mac' }
        when 'MacExpertEncoding' { 'mac-extra' }
        default {
            warn "unimplemented font encoding: $_"
                with $_;
            Nil;
        }
    }

    method is-core-font( FontDict :$dict! ) {
        ! $dict<FontDescriptor>.defined;
    }

    method is-embedded-font( FontDict :$dict! ) {
        do with $dict<FontDescriptor> {
            (.<FontFile>:exists) || (.<FontFile2>:exists) || (.<FontFile3>:exists)
        }
    }

    method load-font-opts(FontDict :$dict! is copy, Bool :$embed = False, |c) {
        my %opt = :!subset;
        %opt<cmap> = $_
            with $dict<ToUnicode>;

        %opt<enc> //= do with $dict<Encoding> {
            when Hash {
                %opt<differences> = $_ with .<Differences>;
                self!base-enc(.<BaseEncoding>, :$dict);
            }
            default { self!base-enc($_, :$dict); }
        }

        %opt<first-char> = $_ with $dict<FirstChar>;
        %opt<last-char>  = $_ with $dict<LastChar>;
        %opt<widths>     = $_ with $dict<Widths>;

        constant SymbolicFlag = 1 +< 5;
        constant ItalicFlag = 1 +< 6;

        $dict = $dict<DescendantFonts>[0]
            if $dict<Subtype> ~~ 'Type0';

        with $dict<FontDescriptor> {
            # embedded font
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
            if $embed {
                with .<FontFile> // .<FontFile2> // .<FontFile3> {
                    my $font-stream = .decoded;
                    $font-stream = $font-stream.encode("latin-1")
                        unless $font-stream ~~ Blob;
                    %opt ,= :$font-stream;
                }
            }

            # See [PDF 32000 Table 114 - Entries in an encoding dictionary]
            %opt<enc> //= do {
                my $embedded := %opt<font-stream>.defined;
                my $symbolic := ?((.<Flags>//0) +& SymbolicFlag);
                # in-case a Type 1 font has been marked as symbolic
                my $type1 = True with .<FontFile> // %opt<differences>;
                $type1 //= .<Subtype> ~~ 'Type1C'
                    with .<FontFile3>;

                $embedded && $symbolic && !$type1
                    ?? 'identity'
                    !! 'std';
            }
        }
        else {
            # no font descriptor. assume core font
            my $family = $dict<BaseFont> // 'courier';
            %opt<weight> = 'bold' if $family ~~ s/:i ['-'|',']? bold //;
            %opt<slant> = $0.lc if $family ~~ s/:i ['-'|',']? (italic|oblique) //;
            %opt<family> = $family;
            %opt<enc> //= do given $family {
                when /:i ^[ZapfDingbats|WebDings]/ {'zapf'}
                when /:i ^[Symbol]/ {'sym'}
                default {'std'}
            }
        }

        %opt;
    }

}
