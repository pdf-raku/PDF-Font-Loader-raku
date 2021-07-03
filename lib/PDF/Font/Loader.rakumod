use v6;

class PDF::Font::Loader:ver<0.5.3> {

    use Font::FreeType;
    use Font::FreeType::Face;
    use PDF::Font::Loader::FontObj;
    use PDF::Font::Loader::FontObj::CID;
    use PDF::Content::Font;
    use PDF::Font::Loader::Dict :&is-core-font, :&load-font-opts;

    proto method load-font($?: |c) is export(:load-font) {*};

    multi method load-font($class = $?CLASS: IO() :$file!, |c) {
        my Blob $font-buf = $file.slurp: :bin;
        $class.load-font(:$font-buf, |c);
    }

    multi method load-font(
        $?: Font::FreeType::Face :$face!,
        Blob :$font-buf!,
        Bool :$embed = True,
        Str  :$enc = $face.font-format eq 'Type 1' || !$embed || $face.num-glyphs <= 255
            ?? 'win'
            !! 'identity-h',
        |c,
    ) {
        my \class = $enc.starts-with('identity') || $enc eq 'cmap'
            ?? PDF::Font::Loader::FontObj::CID
            !! PDF::Font::Loader::FontObj;
        class.new: :$face, :$font-buf, :$enc, :$embed, |c;
    }

    multi method load-font($?: Blob :$font-buf!, |c) is default {
        my Font::FreeType::Face $face = Font::FreeType.face($font-buf);
        $.load-font( :$face, :$font-buf, |c);
    }

    # resolve font name via fontconfig
    multi method load-font($class = $?CLASS: Str :$family!, :$dict, :$quiet, |c) {
        my $file = $class.find-font: :$family, |c;
        my $font := $class.load-font: :$file, :$dict, |c;
        unless $quiet {
            my $name = c<font-name> // $family;
            note "loading font: $name -> $file" with $dict;
        }
        $font;
    }

    # resolve via PDF font dictionary
    multi method load-font($?: PDF::Content::Font:D :$dict!, |c) {
        my %opts = load-font-opts(:$dict, |c);
        $.load-font: |%opts, |c;
    }

    subset Weight is export(:Weight) where /^[thin|extralight|light|book|regular|medium|semibold|bold|extrabold|black|<[0..9]>**3]$/;
    subset Stretch of Str is export(:Stretch) where /^[[ultra|extra]?[condensed|expanded]]|normal$/;
    subset Slant   of Str is export(:Slant) where /^[normal|oblique|italic]$/;

    method find-font($?: Str :$family,
                     Weight  :$weight is copy = 'medium',
                     Stretch :$stretch = 'normal',
                     Slant   :$slant = 'normal',
                     Str     :$lang,
                    ) is export(:find-font) {
        my $pat = '';
        $pat ~= $_ with $family;
        with $weight {
            # convert CSS/PDF numeric weights for fontconfig
            #      000  100        200   300  400     500    600      700  800       900
            $_ =  <thin extralight light book regular medium semibold bold extrabold black>[.substr(0,1).Int]
                if /^<[0..9]>/;
        }
        $pat ~= ':weight=' ~ $weight  unless $weight eq 'medium';
        $pat ~= ':width='  ~ $stretch unless $stretch eq 'normal';
        $pat ~= ':slant='  ~ $slant   unless $slant eq 'normal';
        $pat ~= ':lang=' ~ $_ with $lang;

        my $cmd = run('fc-match', '-f', '%{file}', $pat, :out, :err);
        given $cmd.err.slurp {
            note $_ if $_;
        }
        $cmd.out.slurp
          || die "unable to resolve font: '$pat'"
    }

}

=begin pod

=head2 Name

PDF::Font::Loader

=head1 Synopsis

 # load a font from a file
 use PDF::Font::Loader :load-font;
 use PDF::Content::FontObj;

 my PDF::Content::FontObj $deja;
 $deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
 -- or --
 $deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

 # find/load system fonts; requires fontconfig
 use PDF::Font::Loader :load-font, :find-font;
 $deja = load-font( :family<DejaVu>, :slant<italic> );
 my Str $file = find-font( :family<DejaVu>, :slant<italic> );
 my PDF::Content::FontObj $deja-vu = load-font: :$file;

 # use the font to add text to a PDF
 use PDF::Lite;
 my PDF::Lite $pdf .= new;
 $pdf.add-page.text: {
    .font = $deja;
    .text-position = [10, 600];
    .say: 'Hello, world';
 }
 $pdf.save-as: "/tmp/example.pdf";

=head2 Description

This module provides font loading and handling for
L<PDF::Lite>,  L<PDF::API6> and other PDF modules.

=head2 Methods

=head3 load-font

A class level method to create a new font object.

=head4 C<PDF::Font::Loader.load-font(Str :$file, Bool :$subset, :$enc, :$lang, :$dict);>

Loads a font file.

parameters:
=begin item
C<:$file>

Font file to load. Currently supported formats are:
=item OpenType (C<.otf>)
=item TrueType (C<.ttf>)
=item Postscript (C<.pfb>, or C<.pfa>)
=item CFF (C<.cff>)

TrueType Collections (C<.ttc>) are also accepted, but must be subsetted,
if they are being embedded.

=end item

=begin item
C<:$subset> *(experimental)*

Subset the font for compaction. The font is reduced to the set
of characters that have actually been encoded. This can greatly
reduce the output size when the font is embedded in a PDF file.

This feature currently works on OpenType or TrueType fonts and requires
installation of the experimental L<HarfBuzz::Subset> module.
=end item

=begin item
C<:$enc>

Selects the encoding mode: common modes are `win`, `mac` and `identity-h`.

=item `mac` Macintosh platform single byte encoding
=item `win` Windows platform single byte encoding
=item `identity-h` a degenerative two byte encoding mode

`win` is used as the default encoding for fonts with no more than 255 glyphs. `identity-h` is used otherwise.

It is recommended that you set a single byte encoding such as `:enc<mac>` or `:enc<win>` when it known that
no more that 255 distinct characters will actually be used from the font within the PDF.
=end item

=begin item
C<:$dict>

Associated font dictionary.
=end item

=head4 C<PDF::Font::Loader.load-font(Str :$family, Str :$weight, Str :$stretch, Str :$slant, Bool :$subset, Str :$enc, Str :$lang);>

 my $vera = PDF::Font::Loader.load-font: :family<vera>;
 my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :stretch<condensed> :slant<italic>);

Loads a font by a fontconfig name and attributes.

Note: Requires fontconfig to be installed on the system.

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

Font slat, one of: C<normal>, C<oblique>, or C<italic>

=end item

=begin item
C<:$lang>

A RFC-3066-style language tag. `fontconfig` will select only fonts whose character set matches the preferred lang. See also L<I18N::LangTags|https://modules.raku.org/dist/I18N::LangTags:cpan:UFOBAT>.

=end item

=head3 find-font

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
            );

Locates a matching font-file. Doesn't actually load it.

   my $file = PDF::Font::Loader.find-font: :family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>, :lang<en>;
   say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
   my $font = PDF::Font::Loader.load-font: :$file;

=head2 PDF::Font::Loader::FontObj Methods

The following methods are available on the loaded font:

Font Object Methods
-----------------

### font-name

The font name

### height

Overall font height

### encode

Encodes strings

### decode

   -
Decodes buffers

### kern

Kern text via the font's kerning tables. Returns chunks of text separated by numeric kern widths.

=begin code :lang<raku>
say $font.kern("ABCD"); # ["AB", -18, "CD"]
=end code

### glyph-width

Return the width of a glyph. This is a `rw` method that can be used to globally
adjust a font's glyph spacing for rendering and string-width calculations:

=begin code :lang<raku>
say $vera.glyph-width('V'); # 684;
$vera.glyph-width('V') -= 100;
say $vera.glyph-width('V'); # 584;
=end code

=head3 to-dict

Produces a draft PDF font dictionary.

=head3 cb-finish

Finishing hook for the PDF tool-chain. This produces a finalized PDF font dictionary, including embedded fonts, character widths and encoding mappings.

=head3 is-embedded

Whether a font-file is embedded.

=head3 is-subset

Whether the font has been subsetting

=head3 is-core-font

Whether the font is a core font

=head3 has-encoding

Whether the font has unicode encoding. This is needed to encode or extrac text.

=head3 face

L<Font::FreeType::Face> object associated with the font.

If the font was loaded from a `$dict` object and `is-embedded` is true, the `face` object has been loaded from the embedded font, otherwise its a system-loaded
font, selected to match the font.

=head3 glyphs
=begin code :lang<raku>
use PDF::Font::Loader::Glyph;
my PDF::Font::Loader::Glyph @glyphs = $font.glyphs: "Hi";
say "code-point:{.code-point.raku} cid:{.cid} gid:{.gid} dx:{.dx} dy:{.dy}"
    for @glyphs;
=end code

Maps a string to a set of glyphs:

=item `code-point` is a character code mapping
=item `cid` is the encoded value
=item `gid` is the font index of the glyph in the font object`s `face` attribute.
=item `dx` and `dy` are unscaled font sizes. They should be multiplied by the current font-size/1000 to get the actual sizes.

Loading PDF Fonts
---------------

Fonts can also be loaded from PDF font dictionaries. The following example loads and summarizes page-level fonts:

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

=begin table
name                      |     type    |  encode    | emb | sub
--------------------------+-------------+------------+-----+---
DejaVuSans                |    Type0    | identity-h | yes | no 
Times-Roman               |    Type1    | win        | no  | no 
WenQuanYiMicroHei         |    TrueType | win        | no  | no 
NimbusRoman-Regular       |    Type1    | win        | yes | no 
Cantarell-Oblique         |    Type1    | win        | yes | no 
=end table

=head2 Install

=item PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

=item Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) library and command-line tools is strongly recommended.

=end pod

