#| Loads a font from a PDF font dictionary
class PDF::Font::Loader::Dict {
    use Font::AFM;
    use PDF::Content::Font::CoreFont;
    use PDF::COS::Dict;
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

    sub base-enc($_) {
        when !.defined           { Nil }
        when 'Identity-H'        { 'identity-h' }
        when 'Identity-V'        { 'identity-v' }
        when 'WinAnsiEncoding'   { 'win' }
        when 'MacRomanEncoding'  { 'mac' }
        when 'MacExpertEncoding' { 'mac-extra' }
        when 'StandardEncoding'  { 'std' }
        when /(<<UTF[8|16|32]>>)/ {
            # Predefined table, which we don't fully support
            # We can, at least, detect the encoding
            $0.lc;
        }
        when 'CMap'              { 'cmap' }
        default {
            warn "unimplemented font encoding: $_";
            Nil;
        }
    }

    method is-core-font($?: FontDict :$dict! ) is export(:is-core-font) {
        warn [$dict<Subtype>, font-descriptor($dict)].raku;
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
                        for ^$a.elems;
                }
                when Numeric {
                    # format: code code2 W
                    my $code2 := $_;
                    my $width := $W[$i++];
                    @widths[$_ - $first-char] = $width.round
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

    method load-font-opts($?: FontDict :$dict!, Bool :$embed = False --> Hash) is export(:load-font-opts) {
        my %opt = :!subset, :$embed, :$dict;
        my %encoder;

        with $dict<Encoding> {
            %opt<enc> = do {
                when PDF::COS::Stream {
                    # assume CMAP. See PDF-32000 Table 121
                    # – Entries in a Type 0 font dictionary
                    %encoder<cid-cmap> = $_;
                    base-enc(.<CMapName>) // 'cmap';
                }
                when PDF::COS::Dict {
                    %opt<differences> = $_ with .<Differences>;
                    base-enc(.<BaseEncoding>);
                }
                when Str { base-enc($_); }
            }
        }

        with $dict<ToUnicode> -> PDF::COS::Stream $cmap {
            
            %opt<enc> //= 'cmap';
            %encoder<cmap> //= $cmap;
        }

        %opt<cid> = $dict<Subtype> ~~ 'Type0';
        if %opt<cid> {
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

        %opt<font-descriptor> = $_
            with font-descriptor($dict);

        with %opt<font-descriptor> {
             with .<FontName> {
                 %opt<font-name> = $_;
                 %opt<weight> = $0.lc
                     if /:i (light|bold|heavy|book)/;
                 %opt<width> = $0.lc
                     if /:i (narrow|wide|condensed|expanded)/;
                 %opt<slant> = $0.lc
                     if /:i (italic|oblique)/;
             }

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
            # no font descriptor. unembedded or core font
            my $font-name = $dict<BaseFont> // 'courier';
            my $family = $font-name;

            %opt<weight> = 'bold' if $family ~~ s/:i ['-'|',']? bold //;
            %opt<slant> = $0.lc if $family ~~ s/:i ['-'|',']? (italic|oblique) //;

            if $dict<Subtype> ~~ 'Type1' {
                with PDF::Content::Font::CoreFont.core-font-name($font-name) {
                    # core font
                    %encoder<core-metrics> = Font::AFM.core-font: $_;
                    %opt<font-descriptor> = PDF::COS::Dict;
                    $family = 'serif' if .starts-with('times');
                    $family = 'sans'  if .starts-with('helvetica');
                }
            }
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

=begin pod
=head2 Description

Loads fonts from PDF font dictionaries.

This an internal class, usually invoked from the L<PDF::Font::Loader> `load-font` method to facilitate font loading from PDF font dictionaries.

=head2 Example

The following example loads and summarizes page-level fonts:

=begin code :lang<raku>
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::Font;
use PDF::Content::FontObj;

constant Fmt = "%-30s %-8s %-10s %-3s %-3s";
sub yn($_) {.so ?? 'yes' !! 'no' }

my %SeenFont{PDF::Content::Font};
my PDF::Lite $pdf .= open: "t/freetype.pdf";
say sprintf(Fmt, |<name type encode emb sub>);
say sprintf(Fmt, |<-------------------------- ------- ---------- --- --->);
for 1 .. $pdf.page-count {
    my PDF::Content::Font %fonts = $pdf.page($_).gfx.resources('Font');

    for %fonts.values -> $dict {
        unless %SeenFont{$dict}++ {
            my PDF::Content::FontObj $font = PDF::Font::Loader.load-font: :$dict, :quiet;
            say sprintf(Fmt, .font-name, .type, .encoding, .is-embedded.&yn, .is-subset.&yn)
                given $font;
        }
    }
}
=end code
Produces:

=begin code
name                      |     type    |  encode    | emb | sub
--------------------------+-------------+------------+-----+---
DejaVuSans                |    Type0    | identity-h | yes | no 
Times-Roman               |    Type1    | win        | no  | no 
WenQuanYiMicroHei         |    TrueType | win        | no  | no 
NimbusRoman-Regular       |    Type1    | win        | yes | no 
Cantarell-Oblique         |    Type1    | win        | yes | no 
=end code

=head2 Methods

=head3 load-font-opts
=begin code :lang<raku>
method load-font-opts(Hash :$dict!, Bool :$embed) returns Hash
=end code

Produces a set of L<PDF::Font::Loader> `load-font()` options for
the font dictionary.

=end pod
