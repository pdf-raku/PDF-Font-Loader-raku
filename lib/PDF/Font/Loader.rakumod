use v6;

class PDF::Font::Loader:ver<0.7.3> {

    use Font::FreeType;
    use Font::FreeType::Face;
    use PDF::Content::Font;
    use PDF::Content::Font::CoreFont;
    use PDF::Content::Font::Enc::Type1 :Type1EncodingScheme;
    use PDF::COS;
    use PDF::COS::Dict;
    use PDF::Font::Loader::FontObj;
    use PDF::Font::Loader::FontObj::CID;
    use PDF::Font::Loader::Dict :&load-font-opts;

    proto method load-font($?: |c) is export(:load-font) {*};

    multi method load-font($class = $?CLASS: IO() :$file!, |c) {
        my Blob $font-buf = $file.slurp: :bin;
        $class.load-font: :$font-buf, |c;
    }

    my subset Type1 where .font-format ~~ 'Type 1'|'CFF' && !.is-internally-keyed-cid;
    my subset CIDEncoding of Str where m/^[identity|utf]/;
    multi method load-font(
        $?: Font::FreeType::Face :$face!,
        Blob :$font-buf!,
        Bool :$embed = True,
        Str  :$enc = $face ~~ Type1 || !$embed || ($face.num-glyphs <= 255 && !$face.is-internally-keyed-cid)
            ?? 'win'
            !! 'identity-h',
        Bool :$cid = $face !~~ Type1 && $enc ~~ 'cmap'|CIDEncoding,
        |c,
    ) is hidden-from-backtrace {
        unless c<dict>.defined {
            fail "Type1 fonts cannot be used as a CID font"
                if $cid && $face ~~ Type1;
            fail "'$enc' encoding can only be used with CID fonts"
                if !$cid && $enc ~~ CIDEncoding;
        }
        my \fontobj-class = $cid
            ?? PDF::Font::Loader::FontObj::CID
            !! PDF::Font::Loader::FontObj;
        fontobj-class.new: :$face, :$font-buf, :$enc, :$embed, |c;
    }

    multi method load-font($class = $?CLASS: Blob :$font-buf!, Font::FreeType :$ft-lib, |c) is hidden-from-backtrace {
        my Font::FreeType::Face:D $face = $ft-lib.face($font-buf);
        $class.load-font: :$face, :$font-buf, |c;
    }

    # core font load
    multi method load-font(
        $class is copy = $?CLASS:
        :core-font($)! where .so,
        Str:D :$family!,
        Str:D :$enc = 'win',
        :dict($), :encoder($),
        |c
    ) {
        $class = PDF::Content::Font::CoreFont
            unless c<encoder> || $enc !~~ Type1EncodingScheme;
        $class.load-font: :$family, :$enc, |c;
    }

    # resolve font name via FontConfig
    multi method load-font($class is copy = $?CLASS: Str:D :$family!, PDF::COS::Dict :$dict, :$quiet, |c) is hidden-from-backtrace {
	my Str:D $file = $class.find-font(:$family, |c)
	    || do {
            note "unable to locate font. Falling back to mono-spaced font"
	        unless $quiet;
            %?RESOURCES<font/FreeMono.ttf>.absolute;
        }

        my PDF::Font::Loader::FontObj:D $font := $class.load-font: :$file, :$dict, |c;
	unless $quiet // !$dict {
	    my $name = c<font-name> // $family;
            note "loading font: $name -> $file";
	}
        $font;
    }

    # resolve via PDF font dictionary
    multi method load-font(
        $class is copy = $?CLASS:
        PDF::Content::Font:D :$dict!,
        Bool :$core-font,
        |c) is hidden-from-backtrace {
        my %opts = load-font-opts(:$dict, |c);
        $class = PDF::Content::Font::CoreFont
            if $core-font && PDF::Font::Loader::Dict.is-core-font(:$dict) && %opts<enc> ~~ Type1EncodingScheme && !%opts<encoder>;
        $class.load-font: |%opts, |c;
    }

    subset Weight is export(:Weight) where /^[thin|extralight|light|book|regular|medium|semibold|bold|extrabold|black|<[0..9]>**3]$/;
    subset Stretch of Str is export(:Stretch) where /^[[ultra|extra]?[condensed|expanded]]|normal$/;
    subset Slant   of Str is export(:Slant) where /^[normal|oblique|italic]$/;

    method find-font($?: Str :$family is copy,
                     Weight  :$weight is copy = 'medium',
                     Stretch :$stretch = 'normal',
                     Slant   :$slant = 'normal',
                     UInt    :$limit, # deprecated
                     UInt    :$best is copy = $limit,
                     Bool    :$seq, # deprecated
                     Bool    :$all is copy = $seq,
                     Bool    :$serif, # restrict to serif or sans-serif
                     :cid($), :differences($), :embed($), :enc($), :encoder($),
                     :font-name($), :font-descriptor($), :subset($),
                     *%props,
                    ) is raw is export(:find-font) is hidden-from-backtrace {

        warn ':seq option is deprecated. please use :all, or :$best'
            with $seq;

        warn ':limit option is deprecated. please use :all, or :$best'
           with $limit;

       # https://wiki.archlinux.org/title/Font_configuration/Examples#Default_fonts
        with $serif {
            $family = $_ ?? 'serif' !! 'sans-serif';
        }

        with $weight {
            # convert CSS/PDF numeric weights for fontconfig
            #      000  100        200   300  400     500    600      700  800       900
            $_ =  <thin extralight light book regular medium semibold bold extrabold black>[.substr(0,1).Int]
                if /^<[0..9]>/;
        }

        my $FontConfig := try PDF::COS.required("FontConfig::Pattern");
        if $FontConfig === Nil {
            $all = Nil;
            $best = Nil;
            # Try for an older FontConfig version
            $FontConfig := try PDF::COS.required("FontConfig");
            if $FontConfig === Nil {
                warn "FontConfig is required for the find-font method";
                return Str;
            }
        }
        my $patt = $FontConfig.new: |%props;
        $patt.family = $_ with $family;
        $patt.weight = $weight  unless $weight eq 'medium';
        $patt.width  = $stretch unless $stretch eq 'normal';
        $patt.slant  = $slant   unless $slant eq 'normal';

        if $all || $best {
            my $limit = $best; # deprecated in FontConfig
            $patt.match-series(:$best).map: *.file;
        }
        else {
            with $patt.match -> $match {
                $match.file;
	    }
	    else {
	        Str;
            }
	}
    }

}

=begin pod

=head2 Name

PDF::Font::Loader

=head1 Synopsis

 =begin code :lang<raku>
 # load a font from a file
 use PDF::Font::Loader :&load-font;
 use PDF::Content::FontObj;

 my PDF::Content::FontObj $deja;
 $deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
 -- or --
 $deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

 # find/load the best matching system font
 # *** requires FontConfig ***
 use PDF::Font::Loader :load-font, :find-font;
 $deja = load-font( :family<DejaVu>, :slant<italic> );
 my Str $file = find-font( :family<DejaVu>, :slant<italic> );
 my PDF::Content::FontObj $deja-vu = load-font: :$file;

 # use the font to add text to a PDF
 use PDF::Lite;
 my PDF::Lite $pdf .= new;
 $pdf.add-page.text: {
    .font = $deja, 12;
    .text-position = [10, 600];
    .say: 'Hello, world';
 }
 $pdf.save-as: "/tmp/example.pdf";
 =end code

=head2 Description

This module provides font loading and handling for
L<PDF::Lite>,  L<PDF::API6> and other PDF modules.

=head2 Methods

=head3 load-font

A class level method to load a font from a font file, or pattern creating a new L<PDF::Font::Loader::FontObj> object.

=for code :lang<raku>
multi method load-font(Str:D :$file, Bool :$subset, :$enc, :$dict);

=para Loads a font from a given font file as a L<PDF::Font::Loader::FontObj> object.

=for code :lang<raku>
multi method load-font(Bool :$subset, :$enc, :$lang, :$core-font, *%patt);

=para Finds a font using the `find-font` method on a pattern and loads it. If `:core-font` is True and the pattern
matches a core-font, it is loaded as a L<PDF::Content::Font::CoreFont> object.


Loads a font file.

parameters:
=begin item
C<:$file>

Font file to load. Currently supported formats are:
=item OpenType (C<.otf>)
=item TrueType (C<.ttf>)
=item Postscript (C<.pfb>, or C<.pfa>)
=item CFF (C<.cff>)

TrueType Collections (C<.ttc>) and OpenType Collections (C<*.otc>) are also accepted,
but must be subsetted, if they are being embedded.

=end item

=begin item
C<:$subset>

Subset the font for compaction. The font is reduced to the set
of characters that have actually been encoded. This can greatly
reduce the output size when the font is embedded in a PDF file.

This feature currently works on OpenType, TrueType and CFF fonts and
requires installation of the L<HarfBuzz::Subset> module.
=end item

=begin item
C<:$enc>

Selects the encoding mode: common modes are `win`, `mac` and `identity-h`.

=item `mac` Macintosh platform single byte encoding
=item `win` Windows platform single byte encoding
=item `identity-h` a two byte encoding mode

`win` is used as the default encoding for fonts with no more than 255 glyphs. `identity-h` is used otherwise.

It is recommended that you use a single byte encoding such as `:enc<mac>` or `:enc<win>` when it known that
no more that 255 distinct characters will actually be used from the font within the PDF.
=end item

=begin item
C<:$dict>

Associated font dictionary.
=end item

=begin item
C<:$core-font>

Prefer to load simple Type1 objects as L<PDF::Content::Font::CoreFont>, rather than L<PDF::Font::Loader::FontObj> (both perform the L<PDF::Content::FontObj> role).

=end item

=head4 C<PDF::Font::Loader.load-font(Str :$family, Str :$weight, Str :$stretch, Str :$slant, Bool :$core-font, Bool :$subset, Str :$enc, Str :$lang);>

 my $vera = PDF::Font::Loader.load-font: :family<vera>;
 my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :stretch<condensed> :slant<italic>);

Finds and loads the best-matching system font via L<FontConfig>.

Note: This method requires the Raku L<FontConfig> module to be installed,
unless the `:core-font` option is used, to load only PDF core fonts.

parameters:
=begin item
C<:$family>

Family name of an installed system font to load.

=end item

=begin item
C<:$weight>

Font weight, one of: C<thin>, C<extralight>, C<light>, C<book>, C<regular>, C<medium>, C<semibold>, C<bold>, C<extrabold>, C<black> or a number in the range C<100> .. C<900>.

=end item

=begin item
C<:$stretch>

Font stretch, one of: C<normal>, C<ultracondensed>, C<extracondensed>, C<condensed>, or C<expanded>

=end item

=begin item
C<:$slant>

Font slant, one of: C<normal>, C<oblique>, or C<italic>

=end item

=begin item
C<:$core-font>

Bypass L<FontConfig> and load matching L<PDF::Content::Font::CoreFont> objects, rather than L<PDF::Font::Loader::FontObj> objects (both perform the L<PDF::Content::FontObj> role).

=end item

=begin item
C<:$lang>

A RFC-3066-style language tag. L<FontConfig> will select only fonts whose character set matches the preferred lang. See also L<I18N::LangTags|https://modules.raku.org/dist/I18N::LangTags:cpan:UFOBAT>.

=end item

=begin item
C<*%props>

Any additional options are parsed as L<FontConfig> properties.

=end item

=head3 find-font

=begin code :lang<raku>
use PDF::Font::Loader
    :Weight  # thin|extralight|light|book|regular|medium|semibold|bold|extrabold|black|100..900
    :Stretch # normal|[ultra|extra]?[condensed|expanded]
    :Slant   # normal|oblique|italic
;
find-font(Str :$family,     # e.g. :family<vera>
          Weight  :$weight,
          Stretch :$stretch,
          Slant   :$slant,
          Str     :$lang,   # e.g. :lang<jp>
          Bool    :$all,
          UInt    :$limit,
          UInt    :$best = $limit,
          Bool    :$serif,  # serif(True) or sans-serif(False) fonts
          *%pattern,
          );
=end code

This method requires the optional L<FontConfig> Raku module to be installed.

Locates a matching font-file. Doesn't actually load it.

=begin code :lang<raku>
my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
my $font = PDF::Font::Loader.load-font: :$file;
=end code

The `:all` option returns a sequence of all fonts, ordered best match first. This method may be useful, if you wish to apply your own selection critera.

The `:best($n)` is similar to `:all`, but returns at most the `$n` best matching fonts.

Any additional options are treated as a L<FontConfig> pattern attributes. For example `:spacing<mono>` will select monospace fonts.

=begin code :lang<raku>
use PDF::Font::Loader;
use Font::FreeType;
use Font::FreeType::Face;
my Font::FreeType $ft .= new;
my $series = PDF::Font::Loader.find-font(:best(10), :!serif, :weight<bold>,);
my Str @best = $series.Array;
# prefer a font with kerning
my Str $best-font = @best.first: -> $file {
    my Font::FreeType::Face $face = $ft.face: $file;
    $face.has-kerning;
}
# fall-back to best matching font without kerning
$best-font //= @best.head;

note "best font: " ~ $best-font;
=end code

=end pod

