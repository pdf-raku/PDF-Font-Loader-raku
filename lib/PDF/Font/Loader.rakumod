use v6;

class PDF::Font::Loader:ver<0.5.1> {

    use Font::FreeType;
    use Font::FreeType::Face;
    use PDF::Font::Loader::FontObj;
    use PDF::Content::Font;
    use PDF::Font::Loader::Dict :&is-core-font, :&load-font-opts;

    proto method load-font($?: |c) is export(:load-font) {*};

    multi method load-font($class = $?CLASS: IO() :$file!, |c) {
        my Blob $font-buf = $file.slurp: :bin;
        $class.load-font(:$font-buf, |c);
    }

    multi method load-font($?: Font::FreeType::Face :$face!, Blob :$font-buf!, |c) {
        PDF::Font::Loader::FontObj.new: :$face, :$font-buf, |c;
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

=head1 NAME

PDF::Font::Loader

=head1 SYNPOSIS

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

=head1 DESCRIPTION

This module provdes font loading and handling for
L<PDF::Lite>,  L<PDF::API6> and other PDF modules.

=head1 METHODS

=head3 load-font

A class level method to create a new font object.

=head4 C<PDF::Font::Loader.load-font(Str :$file, Bool :$subset, :$enc, $lang);>

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

=head1 INSTALL

- PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

- Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) library and command-line tools is strongly recommended.

=end pod

