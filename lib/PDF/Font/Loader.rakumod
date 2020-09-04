use v6;

class PDF::Font::Loader:ver<0.3.1> {

    use Font::FreeType;
    use Font::FreeType::Face;
    use PDF::Font::Loader::FreeType;
    use PDF::Font::Loader::Type1;
    use PDF::Font::Loader::Dict;
    subset TrueTypeLike of Font::FreeType::Face where .font-format ~~ 'TrueType'|'CFF';
    subset Type1Like of Font::FreeType::Face where .font-format ~~'Type 1';

    proto method load-font($?: |c) is export(:load-font) {*};

    multi method load-font($class = $?CLASS: IO() :$file!, |c) {
        my Blob $font-stream = $file.slurp: :bin;
        $class.load-font(:$font-stream, |c);
    }

    multi method load-font($?: Font::FreeType::Face :$face!, Blob :$font-stream!, |c) {
        given $face {
            when TrueTypeLike {
                fail "unable to handle TrueType Collections"
                    if $font-stream.subbuf(0,4).decode('latin-1') eq 'ttcf';
                PDF::Font::Loader::FreeType.new( :$face, :$font-stream, |c);
            }
            when Type1Like {
                PDF::Font::Loader::Type1.new( :$face, :$font-stream, |c);
            }
            default { fail "unable to handle font of format {.font-format}"; }
        }
    }

    multi method load-font($?: Blob :$font-stream!, |c) is default {
        state Font::FreeType $free-type;
        $free-type //= Font::FreeType.new;
        my Font::FreeType::Face $face = $free-type.face($font-stream);
        $.load-font( :$face, :$font-stream, |c);
    }

    # resolve font name via fontconfig
    multi method load-font($class = $?CLASS: Str :$family!, |c) {
        my $file = $class.find-font(:$family, |c);
        $class.load-font: :$file, |c;
    }

    multi method load-font($?: Hash :$dict!, |c) {
        my %opts = PDF::Font::Loader::Dict.load-font-opts( :$dict, |c);
        $.load-font( |%opts );
    }

    subset Weight is export(:Weight) where /^[thin|extralight|light|book|regular|medium|semibold|bold|extrabold|black|<[0..9]>**3]$/;
    subset Stretch of Str is export(:Stretch) where /^[[ultra|extra]?[condensed|expanded]]|normal$/;
    subset Slant   of Str is export(:Slant) where /^[normal|oblique|italic]$/;

    method find-font($?: Str :$family!,
                     Weight  :$weight is copy = 'medium',
                     Stretch :$stretch = 'normal',
                     Slant   :$slant = 'normal') is export(:find-font) {
        my $pat = $family;
        with $weight {
            # convert CSS/PDF numeric weights for fontconfig
            #      000  100        200   300  400     500    600      700  800       900
            $_ =  <thin extralight light book regular medium semibold bold extrabold black>[.substr(0,1).Int]
                if /^<[0..9]>/;
        }
        $pat ~= ':weight=' ~ $weight  unless $weight eq 'medium';
        $pat ~= ':width='  ~ $stretch unless $stretch eq 'normal';
        $pat ~= ':slant='  ~ $slant   unless $slant eq 'normal';

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

 my $deja = PDF::Font::Loader.load-font: :file<t/fonts/DejaVuSans.ttf>;
 my $deja = load-font( :file<t/fonts/DejaVuSans.ttf> );

 # find/load system fonts; requires fontconfig
 use PDF::Font::Loader :load-font, :find-font;
 $deja = load-font( :family<DejaVu>, :slant<italic> );
 my Str $file = find-font( :family<DejaVu>, :slant<italic> );
 my $deja-vu = load-font: :$file;

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
L<PDF::Lite|https://pdf-raku.github.io/PDF-Lite-raku>,  L<PDF::API6|https://pdf-raku.github.io/PDF-API6> and other PDF modules.

=head1 METHODS

=head3 load-font

A class level method to create a new font object.

=head4 C<PDF::Font::Loader.load-font(Str :$file);>

Loads a font file.

parameters:
=begin item
C<:$file>

Font file to load. Currently supported formats are:
=item2 Open-Type (C<.otf>)
=item2 True-Type (C<.ttf>)
=item2 Postscript (C<.pfb>, or C<.pfa>)

=end item

=head4 C<PDF::Font::Loader.load-font(Str :$family);>

 my $vera = PDF::Font::Loader.load-font: :family<vera>;
 my $deja = PDF::Font::Loader.load-font: :family<Deja>, :weight<bold>, :width<condensed> :slant<italic>);

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
            );

Locates a matching font-file. Doesn't actually load it.

   my $file = PDF::Font::Loader.find-font(:family<Deja>, :weight<bold>, :width<condensed>, :slant<italic>);
   say $file;  # /usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-BoldOblique.ttf
   my $font = PDF::Font::Loader.load-font( :$file )';

=head1 INSTALL

- PDF::Font::Loader depends on Font::FreeType which further depends on the [freetype](https://www.freetype.org/download.html) library, so you must install that prior to installing this module.

- Installation of the [fontconfig](https://www.freedesktop.org/wiki/Software/fontconfig/) package and command-line tools is strongly recommended.

=head1 BUGS AND LIMITATIONS

=item Automatic font subsetting is not yet implemented. I.E. fonts are always fully embedded, which may result in large PDF files.

As a work-around, font subsetting and reduction can be done manually, using the `pyftsubset` utlity, which is included in the Debian `fonttools` package.

For example, to create a latin-1 subset of the DejaVuSans font:

    `$ pyftsubset t/fonts/DejaVuSans.ttf --output-file=/tmp/dejavu-latin.ttf --layout-features=\* --no-hinting --unicodes="U+0000-00FF"`

Changing the 'Hello, World' example to use this font:

    # load a font from a file
    use PDF::Font::Loader :load-font;

    my $deja = load-font( :file</tmp/dejavu-latin.ttf> );

    # use the font to add text to a PDF
    use PDF::Lite;
    my PDF::Lite $pdf .= new;
    $pdf.add-page.text: {
       .font = $deja;
       .text-position = [10, 600];
       .say: 'Hello, world';
    }
    $pdf.save-as: "/tmp/example.pdf";

Reduces the file size of `example.pdf` from 373K to 15K.

=end pod

