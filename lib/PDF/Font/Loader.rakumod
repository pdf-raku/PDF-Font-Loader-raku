use v6;

unit class PDF::Font::Loader:ver<0.8.13>;

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

multi sub find-afm(IO:D $file where .extension ~~ 'pfa'|'pfb') {
    my $afm-file = $file.path.subst(/'.pf'[a|b]$/, '.afm');
    $afm-file.IO.e ?? $afm-file !! Str;
}
multi sub find-afm(IO:D $file where .extension ~~ 'PFA'|'PFB') {
    my $afm-file = $file.path.subs(/'.PF'[A|B]$/, '.AFM');
    $afm-file.IO.e ?? $afm-file !! Str;
}
multi sub find-afm($) { Str }

sub is-cid(Font::FreeType::Face $_, Blob $font-buf) {
    .is-internally-keyed-cid || (
        .font-format ~~ 'OpenType'|'TrueType'
        && $font-buf.subbuf(0,4).decode('latin-1') eq 'ttcf'
    )
}

sub is-type1(Font::FreeType::Face $_, Blob $font-buf) {
    .font-format ~~ 'Type 1'|'CFF'|'OpenType'
    && !.&is-cid($font-buf);
}
my subset CIDEncoding of Str where m/^[identity|utf]/;

multi method load-font(
    $?: Font::FreeType::Face :$face!,
    Blob :$font-buf!,
    Bool :$embed = True,
    Str  :$enc is copy,
    |c,
) is hidden-from-backtrace {
    my $is-cid = do with c<dict> {
        fail "missing :enc option for :dict" without $enc;
        .<Subtype> ~~ 'Type0';
    }
    else {
        $enc //= $face.&is-type1($font-buf) || !$embed || ($face.num-glyphs <= 255 && !$face.&is-cid($font-buf))
        ?? 'win'
        !! 'identity-h';
        $enc ~~ 'cmap'|CIDEncoding;
    }
    my \fontobj-class = $is-cid
        ?? PDF::Font::Loader::FontObj::CID
        !! PDF::Font::Loader::FontObj;
    fontobj-class.new: :$face, :$font-buf, :$enc, :$embed, |c;
}

multi method load-font($class = $?CLASS: Blob :$font-buf!, UInt:D :$index = 0, Font::FreeType :$ft-lib, IO :$file, |c) is hidden-from-backtrace {
    my Font::FreeType::Face:D $face = $ft-lib.face($font-buf, :$file, :$index);
    $class.load-font: :$face, :$font-buf, |c;
}

multi method load-font($class = $?CLASS: IO:D() :$file!, Str :$afm = find-afm($file), |c) {
    my Blob $font-buf = $file.slurp: :bin;
    $class.load-font: :$font-buf, :$afm, :$file, |c;
}

# core font load
multi method load-font(
    $class is copy = $?CLASS:
    :core-font($)! where .so,
    Str:D :$family!,
    Str:D :$enc = 'win',
    :dict($),
    |c
) {
    $class = PDF::Content::Font::CoreFont
        unless c<encoder> || $enc !~~ Type1EncodingScheme;
    $class.load-font: :$family, :$enc, |c;
}

# resolve font name via FontConfig
multi method load-font($class is copy = $?CLASS: Str:D :$family!, PDF::COS::Dict :$dict, :$quiet, :all($), :best($), |c) is hidden-from-backtrace {
    my IO() $file;
    my $index = 0;
    with $class.match-font(:$family, |c) {
        $file  = .file;
        $index = .index;
    }
    else {
        note "Unable to locate font. Falling back to mono-spaced font"
            unless $quiet;
        $file = %?RESOURCES<font/FreeMono.ttf>.IO;
    }

    my PDF::Font::Loader::FontObj:D $font := $class.load-font: :$file, :$index, :$dict, |c;
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

method match-font($?: Str :$family is copy,
                 Weight  :$weight is copy = 'medium',
                 Stretch :$stretch = 'normal',
                 Slant   :$slant = 'normal',
                 UInt    :$best is copy,
                 Bool    :$all is copy,
                 Bool    :$serif, # restrict to serif or sans-serif
                 :cid($), :differences($), :embed($), :enc($), :encoder($),
                 :font-name($), :font-descriptor($), :subset($),
                 *%props,
                ) is raw is export(:match-font) is hidden-from-backtrace {
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
            return Nil;
        }
    }
    my $patt = $FontConfig.new: |%props;
    $patt.family = $_ with $family;
    $patt.weight = $weight  unless $weight eq 'medium';
    $patt.width  = $stretch unless $stretch eq 'normal';
    $patt.slant  = $slant   unless $slant eq 'normal';

    if $all || $best {
        $patt.match-series(:$all, :$best);
    }
    else {
        $patt.match;
    }
}

method find-font(
     $class = $?CLASS:
    UInt    :$best,
    Bool    :$all,
    Bool    :$quiet,
    |c) is export(:find-font) {
    with $class.match-font(:$all, :$best, |c) {
        $all || $best
        ?? .map(*.file)
        !! .file
    }
    else {
        note "Unable to locate font. Falling back to mono-spaced font"
            unless $quiet;
        %?RESOURCES<font/FreeMono.ttf>.IO.path;
    }
}

multi method can-subset returns Bool {
    (try require HarfBuzz::Subset) !=== Nil;
}

multi method can-subset(IO() $file!) returns Bool is hidden-from-backtrace {
    my Blob $font-buf = $file.slurp: :bin;
    $.can-subset
    && $font-buf.subbuf(0,4).decode('latin-1') ne 'wOFF'
    && Font::FreeType.face($font-buf).font-format ~~ 'TrueType'|'OpenType'
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

=para Finds the best matching font using the `find-font` method on a pattern and loads it. If `:core-font` is True and the pattern
matches a core-font, it is loaded as a L<PDF::Content::Font::CoreFont> object.

parameters:
=begin item
C<:$file>

Font file to load. Currently supported formats are:
=item OpenType (C<.otf>)
=item TrueType (C<.ttf>)
=item Postscript (C<.pfb>, or C<.pfa>)
=item CFF (C<.cff>)

TrueType Collections (C<*.ttc>) and OpenType Collections (C<*.otc>) are also accepted.

The C<:index> option can be used to select a font from the collection.

They must be subsetted, if they are being embedded.

=for code :lang<raku>
my PDF::Content::FontObj $otc-font-italic = load-font :file<t/fonts/EBGaramond12.otc>, :subset, :index(1);

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

`win` is used as the default encoding for type-1 fonts. `identity-h` is used for CID fonts (most `TrueType` and `OpenType` fonts).
=end item

=begin item
UInt C<:$index>

The index of a font in a font-collection. This option is applicable to TrueType collections (C<*.ttc>) and OpenType collections (C<*.otc>).
=end item

=begin item
C<:$dict>

Associated PDF font dictionary.
=end item

=begin item
C<:$core-font>

Prefer to load simple Type1 objects as L<PDF::Content::Font::CoreFont>, rather than L<PDF::Font::Loader::FontObj> (both perform the L<PDF::Content::FontObj> role).

=end item

=for code :lang<raku>
multi method load-font(Str :$family, Str :$weight, Str :$stretch, Str :$slant, Bool :$core-font, Bool :$subset, Str :$enc, Str :$lang);

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
          UInt    :$best,
          Bool    :$serif,  # serif(True) or sans-serif(False) fonts
          *%pattern,
          );
=end code

This method requires the optional L<FontConfig> Raku module to be installed.

Locates, font-files after sorting system fonts using the pattern.
Normally the best matching font-file is returned, or multiple font
files can be returned using the `:best($n)` or `:all` options.

=begin code :lang<raku>
my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
my $font = PDF::Font::Loader.load-font: :$file;
=end code

The `:all` option returns a sequence of all fonts, ordered by best to worst matching. This method may be useful, if you wish to apply your own selection criteria.

The `:best($n)` is similar to `:all`, but returns at most the `$n` best matching fonts.

Any additional options are treated as a L<FontConfig> pattern attributes. For example `:spacing<mono>` will select mono-space fonts.

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

=head3 can-subset

=for code :lang<raku>
multi method can-subset returns Bool;

=para Returns C<True> if L<PDF::Font::Loader> has general font subsetting capability; I.E. the optional L<HarfBuzz::Subset> module has been installed.

=for code :lang<raku>
multi method can-subset(IO() $font-file) returns Bool;

=para Returns C<True> if L<PDF::Font::Loader> has font subsetting capability for the particular font.

=para This will usually be be C<True> for C<TrueType> and C<OpenType> fonts (extensions C<.ttf>, C<.otf>, C<.ttc>, and C<.otc>), if the optional L<HarfBuzz::Subset> module has been installed.

=end pod

