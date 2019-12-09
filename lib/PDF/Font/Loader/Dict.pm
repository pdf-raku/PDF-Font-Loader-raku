
#| Loads a font from a PDF font dictionary (experimental)
class PDF::Font::Loader::Dict {
    my subset FontDict of Hash where .<Type> ~~ 'Font';

    method !base-enc($_, :$dict!) {
        when 'Identity-H'       {'identity-h' }
        when 'WinAnsiEncoding'  { 'win' }
        when 'MacRomanEncoding' { 'mac' }
        default {
            warn "ignoring font encoding: $_"
                with $_;
            Mu;
        }
    }

    method is-core-font( FontDict :$dict! ) {
        ! $dict<FontDescriptor>.defined;
    }

    method is-embedded-font( FontDict :$dict! ) {
        defined do with $dict<FontDescriptor> {
            .<FontFile> // .<FontFile2> // .<FontFile3>
        }
    }

    method load-font-opts(FontDict :$dict! is copy, Bool :$embed = True, |c) {
        my %opt;

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
        %opt<widths>     = $_ with $dict<Widths>; # todo: handle in PDF::Font::Loader

        constant SymbolicFlag = 1 +< 5;
        constant ItalicFlag = 1 +< 6;

        $dict = $dict<DescendantFonts>[0]
            if $dict<Subtype> ~~ 'Type0';

        with $dict<FontDescriptor> {
            # embedded font
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
                    %opt<font-stream> = $font-stream;
                }
            }

            # See [PDF 32000 Table 114 - Entries in an encoding dictionary]
            %opt<enc> //= %opt<font-stream>.defined || $dict<Flags> +& SymbolicFlag
                ?? 'std'
                !! 'identity';

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
