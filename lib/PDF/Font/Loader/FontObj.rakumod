use PDF::Content::FontObj;

#| Loaded font objects
unit class PDF::Font::Loader::FontObj
    does PDF::Content::FontObj;

use PDF::COS;
use PDF::COS::Dict;
use PDF::COS::Name;
use PDF::COS::Stream;
use PDF::IO::Blob;
use PDF::IO::Util :pack;
use NativeCall;
use PDF::Font::Loader::Enc::CMap;
use PDF::Font::Loader::Enc::Identity16;
use PDF::Font::Loader::Enc::Type1;
use PDF::Font::Loader::Enc::Unicode;
use PDF::Font::Loader::Glyph;
use PDF::Font::Loader::Type1::Stream;
use Font::FreeType:ver(v0.3.0+);
use Font::FreeType::Face;
use Font::FreeType::Error;
use Font::FreeType::Raw;
use Font::FreeType::Raw::Defs;
use Font::FreeType::Raw::TT_Sfnt;
use PDF::Content:ver(v0.4.8+);
use PDF::Content::Font;
use PDF::Content::Font::CoreFont;

constant Px = 64.0;
sub prefix:</>($name) { PDF::COS::Name.COERCE($name) };
sub bit(\n) { 1 +< (n-1) }

my enum FontFlags is export(:FontFlags) «
    :FixedPitch(bit(1))
    :Serif(bit(2))
    :Symbolic(bit(3))
    :Script(bit(4))
    :Nonsymbolic(bit(6))
    :Italic(bit(7))
    :AllCap(bit(17))
    :SmallCap(bit(18))
    :ForceBold(bit(19))
    »;
enum <Width Height>;

has Font::FreeType::Face:D $.face is required handles<underline-thickness underline-position>;
use PDF::Font::Loader::Enc;
has PDF::Font::Loader::Enc $!encoder handles <decode first-char last-char widths has-encoding glyph get-glyphs glyph-width height stringwidth encode-cids>;
method encoder { $!encoder }
has Blob $.font-buf;
has PDF::COS::Dict $!dict;
my subset EncodingScheme is export(:EncodingScheme) where 'mac'|'win'|'zapf'|'sym'|'identity'|'identity-h'|'identity-v'|'std'|'mac-extra'|'cmap'|'utf8'|'utf16'|'utf32';
has EncodingScheme $.enc is required;
has Bool $.subset = False;
has Str:D $.family          = $!face.family-name // 'Untitled';
has Str:D $.font-name is rw = $!face.postscript-name // $!family;
# Font descriptors are needed for all but core fonts
has PDF::COS::Dict() $.font-descriptor = %( :Type(/'FontDescriptor'), :FontName(/$!font-name));
has Bool $.embed = $!font-descriptor.defined;
has Bool $!finished;
has Bool $!gids-updated;
has Bool $!build-widths;

sub subsetter {
    PDF::COS.required("HarfBuzz::Subset")
}

submethod TWEAK(
    EncodingScheme:D :$!enc!,
    PDF::COS::Dict :$!dict,
    :@cid-to-gid-map,
    :@differences,
    :%encoder,
    Str :$prefix is copy,
) {

    if $!embed {
        if self!font-type-entry eq 'TrueType' {
            given $!font-buf.subbuf(0,4).decode('latin-1') {
                when 'ttcf' {
                    unless $!subset {
                        # Its a TrueType collection which is not directly supported as a format,
                        # however, HarfBuzz::Subset will convert it for us.
                        die "The HarfBuzz::Subset module is required to embed TrueType Collection font $!font-name"
                            if (try subsetter()) === Nil;
                        $!subset = True;
                    }
                }
                when 'wOFF' {
                    die "unable to embed wOFF font $!font-name";
                }
            }
        }

        if $!subset && (try subsetter()) === Nil {
            warn "HarfBuzz::Subset is required for font subsetting";
            $!subset = False;
        }
    }
    else {
        # $!subset incompatibile with !$embed
        $!subset = False
    }

    if $!subset {
        if $!face.font-format ~~ 'TrueType'|'OpenType'|'CFF' {
            $prefix ||= ("A".."Z").pick(6).join;
            $!font-name ~~ s/^[<[A..Z]>**6"+"]?/{$prefix ~ "+"}/;
            $!font-descriptor<FontName> = /$!font-name;
        }
        else {
           warn  "unable to subset font $!font-name of type {$!face.font-format}";
           $!subset = False;
        }
    }

    # See [PDF 32000 Table 117 – Entries in a CIDFont dictionary]
    warn "ignoring /CIDToGIDMap for {self.encoding} encoding"
        if $!enc.starts-with('identity') && (%encoder<cid-to-gid-map>:delete);

    $!encoder = do {
        when $!enc ~~ 'utf8'|'utf16'|'utf32' {
            PDF::Font::Loader::Enc::Unicode.new: :$!face, :$!enc, |%encoder, :@cid-to-gid-map;
        }
        when $!enc eq 'cmap' || %encoder<cmap>.defined {
            PDF::Font::Loader::Enc::CMap.new: :$!face, |%encoder, :@cid-to-gid-map;
        }
        when $!enc ~~ 'identity-h'|'identity-v' {
            PDF::Font::Loader::Enc::Identity16.new: :$!face, |%encoder;
        }
        default {
            PDF::Font::Loader::Enc::Type1.new: :$!enc, :$!face, |%encoder, :@cid-to-gid-map;
        }
    }

    $!encoder.protect({ $!encoder.differences = @differences })
        if @differences;
    # Be careful not to start adding widths if an existing
    # font dictionary doesn't already have them.
    $!build-widths = %encoder<widths>.so || !$!dict.defined;
    $!finished = ! $!build-widths;

    PDF::Content::Font.make-font($_, self)
        with $!dict;
}

method glyphs(|c) is DEPRECATED<get-glyphs> { self.get-glyphs(|c) }

method load-font(|c) {
    PDF::COS.required('PDF::Font::Loader').load-font: |c;
}

method decode-cids(Str $byte-str) {
    my @cids = $!encoder.decode($byte-str, :cids);
    if $!build-widths || $!encoder.cid-to-gid-map {
        $!encoder.get-glyphs: @cids;
    }
    @cids;
}

method encode($text is raw, |c) {
    if $!build-widths || $!encoder.cid-to-gid-map {
        $!encoder.get-glyphs: $!encoder.encode($text, :cids);
    }
    $!encoder.encode($text, |c);
}

method !font-type-entry returns Str {
    given $!face.font-format {
        when 'Type 1'|'CFF'|'OpenType' { 'Type1' }
        when 'TrueType' { 'TrueType' }
        default { fail "unable to handle font type: $_" }
    }
}

method !font-file-entry {
    given $!face.font-format {
        when 'TrueType'       { 'FontFile2' }
        when 'OpenType'|'CFF' { 'FontFile3' }
        default               { 'FontFile' }
    }
}

method !make-type1-font-file($buf) {
    my PDF::IO::Blob() $encoded = $buf;
    my PDF::Font::Loader::Type1::Stream $stream .= new: :$buf;
    my %dict := %(
        Length1 => $stream.length[0],
        Length2 => $stream.length[1],
        Length3 => $stream.length[2],
    );

    PDF::COS::Stream.COERCE: %( :$encoded, :%dict );
}

method !make-other-font-file(Blob:D $buf) {
    my $decoded = PDF::IO::Blob.new: $buf;
    my %dict := %(
        :Length1($buf.bytes),
        :Filter(/<FlateDecode>),
    );

    given $!face.font-format {
        when 'OpenType' {
            %dict<Subtype> = $!face.is-internally-keyed-cid
                ?? /<CIDFontType0C> !! /<OpenType>;
        }
        when 'CFF' {
            %dict<Subtype> = /<Type1C>;
            if Font::FreeType.^ver <= v0.5.4 {
                # Peek at the buffer to distinguish simple CFF from OpenType/CFF
                # See https://learn.microsoft.com/en-us/typography/opentype/spec/otff#organization-of-an-opentype-font
                my subset OpenTypeCFF of Blob:D where .subbuf(0,4).decode('latin-1') eq 'OTTO';
                %dict<Subtype> = /<OpenType>
                    if $buf ~~ OpenTypeCFF;
            }
        }
    }

    PDF::COS::Stream.COERCE: { :$decoded, :%dict, };
}

method !make-font-file($buf) {
    $!face.font-format eq 'Type 1'
        ?? self!make-type1-font-file($buf)
        !! self!make-other-font-file($buf);
}

sub pclt-font-weight(Int $w) {
    given ($w + 7) / 14 {
        when * < .1 { 100 }
        when * > .9 { 900 }
        default { .round(.1) * 100 }
    }
}

method font-descriptor {

    with $!font-descriptor -> $dict {
        # some info can be dug out of true-type tables
        my TT_Postscript $tt-post .= load(:$!face);
        my TT_PCLT $tt-pclt .= load(:$!face);

        my Numeric $Ascent = $!face.ascender;
        my Numeric $Descent = $!face.descender;
        my Numeric @FontBBox[4] = $!face.bounding-box.Array;
        my UInt $Flags;
        $Flags +|= FixedPitch if $!face.is-fixed-width;
        $Flags +|= Italic if $!face.is-italic;
        with $tt-pclt {
            $Flags +|= Serif if (.serifStyle +> 6) == 2;
        }

        # set up required fields
        my UInt $CapHeight  = do with $tt-pclt { .capHeight }
            else { (self!char-height( 'X'.ord) || $Ascent * 0.9).round };
        my UInt $XHeight    = do with $tt-pclt { .xHeight }
            else { (self!char-height( 'x'.ord) || $Ascent * 0.7).round };
        my Int $ItalicAngle = do with $tt-post { .italicAngle.round }
        else { $!face.is-italic ?? -12 !! 0 };

        my $FontName  = /($!font-name);
        my $FontFamily = $!embed ?? /($!family) !! $FontName;
        # google impoverished guess
        my UInt $StemV = $!face.is-bold ?? 110 !! 80;

        for (
            :$FontName, :$FontFamily, :$Flags,
            :$Ascent, :$Descent, :@FontBBox,
            :$ItalicAngle, :$StemV, :$CapHeight, :$XHeight,
        ) {
            $dict{.key} //= .value;
        }

        # try for a few more properties

        with TT_OS2.load: :$!face {
            $dict<FontWeight> //= .usWeightClass;
            $dict<AvgWidth> //= .xAvgCharWidth;

            if $!face.is-internally-keyed-cid {
                # applicable to CID font descriptors
                my $buf = .panose.Blob;
                $buf.prepend: (.sFamilyClass div 256, .sFamilyClass mod 256);
                my $Panose = hex-string => $buf.decode: "latin-1";
                $dict<Style> //= %( :$Panose );
            }
        }

        with $tt-pclt {
            $dict<FontWeight> //= pclt-font-weight(.strokeWeight)
        }

        with TT_HoriHeader.load: :$!face {
            $dict<Leading>  //= .lineGap;
            $dict<MaxWidth> //= .advanceWidthMax;
        }

        if $!embed {
            $dict{self!font-file-entry} //= self!make-font-file($!font-buf);
        }
        else {
            $dict{self!font-file-entry}:delete;
        }

    }
    $!font-descriptor;
}

method encoding {

    constant %EncName = %(
        :win<WinAnsiEncoding>,
        :mac<MacRomanEncoding>,
        :mac-extra<MacExpertEncoding>,
        :identity-h<Identity-H>,
        :identity-v<Identity-V>,
        :identity<Identity>,
        :std<StandardEncoding>,
        :cmap<CMap>,
    );

    %EncName{$!enc};
}

sub charset-to-unicode(%charset) {
    my uint32 @to-unicode;
    for %charset.kv -> $ord, $cid {
        @to-unicode[$cid] = $ord;
    }
    @to-unicode;
}

method CIDSystemInfo {
    do with $!encoder.cmap {
        .<CIDSystemInfo>
    } // {
        :Ordering<Identity>,
        :Registry($!font-name),
        :Supplement(0),
    }
}

method make-to-unicode-stream {

    $!encoder.cmap //= do {
        my PDF::COS::Name() $CMapName = 'to-unicode-' ~ $!font-name;
        my PDF::COS::Name() $Type = 'CMap';

        PDF::COS::Stream.COERCE: %( :dict{
            :$Type,
            :$CMapName,
            :$.CIDSystemInfo,
        });
    }

    my $to-unicode := $!subset
        ?? charset-to-unicode($!encoder.charset)
        !! $!encoder.to-unicode;

    $!encoder.cmap.decoded = $!encoder.make-to-unicode-cmap(:$to-unicode);
    $!encoder.cmap;
}

# finalize the font, depending on how it's been used
method finish-font($dict, :$save-widths) {
    $dict<ToUnicode> //= self.make-to-unicode-stream
        if $!encoder.encoding-updated;
    if $save-widths {
        $dict<FirstChar> = $.first-char;
        $dict<LastChar>  = $.last-char;
        $dict<Widths>    = $.widths;
    }
    if $!encoder.differences -> $Differences {
        my %enc = :Type(/<Encoding>), :$Differences;

        with self.encoding {
            %enc<BaseEncoding> = /($_)
                unless $_ ~~ 'CMap'|'StandardEncoding'; # implied anyway
        }

        $dict<Encoding> = %enc;
    }
}

method make-dict {
    my $Type = /(<Font>);
    my $Subtype  = /(self!font-type-entry);
    my $BaseFont = /($!font-name);
    my $Encoding = /(self.encoding);

    my PDF::COS::Dict() $dict = %(
        :$Type,
        :$Subtype,
        :$BaseFont,
        :$Encoding,
    );

    with self.font-descriptor {
        .<Flags> +|= Nonsymbolic;
        $dict.self<FontDescriptor> = $_;
    }

    $dict;
}

method to-dict {
     $!encoder.protect: {
         $!dict //= PDF::Content::Font.make-font(self.make-dict, self);
     }
}

method !char-height(UInt $char-code) {
    my $face-struct = $!face.raw;
    my $glyph-slot = $face-struct.glyph;
    my $scale = 1000 / ($!face.units-per-EM || 1000);
    my FT_UInt $idx = $face-struct.FT_Get_Char_Index( $char-code );
    if $idx {
        ft-try({ $face-struct.FT_Load_Glyph( $idx, FT_LOAD_NO_SCALE); });
        $glyph-slot.metrics.height * $scale;
    }
    else {
        0
    }
}

method kern(Str $text) {
    my Numeric      $kernwidth = 0.0;
    my @chunks;

    if $!face.has-kerning {
        my FT_UInt      $prev-gid = 0;
        my FT_Vector    $kerning .= new;
        my FT_Face      $face-struct = $!face.raw;
        my FT_GlyphSlot $glyph-slot = $face-struct.glyph;
        my Str          $str = '';
        my $scale = 1000 / $!face.units-per-EM;

        for $text.ords -> $char-code {
            my FT_UInt $this-gid = $face-struct.FT_Get_Char_Index( $char-code );
            if $this-gid {
                if $prev-gid {
                    ft-try({ $face-struct.FT_Get_Kerning($prev-gid, $this-gid, FT_KERNING_UNSCALED, $kerning); });
                    my $dx := ($kerning.x * $scale).round;
                    if $dx {
                        @chunks.push: $str;
                        @chunks.push: $dx;
                        $kernwidth += $dx;
                        $str = '';
                    }
                }
                $str ~= $char-code.chr;
                $prev-gid = $this-gid;
            }
        }

        @chunks.push: $str
            if $str.chars;
    }
    else {
        @chunks.push: $text;
    }

    @chunks, self.stringwidth($text) + $kernwidth.round;
}

method shape(Str $text) {
    my Numeric $width = 0.0;
    my @shaped;

    if $!face.has-kerning {
        my FT_UInt      $prev-gid = 0;
        my FT_Vector    $kerning .= new;
        my FT_Face      $face-struct = $!face.raw;
        my FT_GlyphSlot $glyph-slot = $face-struct.glyph;
        my uint16       @cids;
        my $scale = 1000 / $!face.units-per-EM;

        for $text.ords -> $ord {
            my uint16 $cid = $!encoder.protect: { $!encoder.charset{$ord} // $!encoder.add-encoding($ord) };
            if $cid {
                $width += self.glyph($cid).ax;
                my FT_UInt $this-gid = $face-struct.FT_Get_Char_Index( $ord );
                if $prev-gid && $this-gid {
                    ft-try({ $face-struct.FT_Get_Kerning($prev-gid, $this-gid, FT_KERNING_UNSCALED, $kerning); });
                    my $dx := ($kerning.x * $scale).round;
                    my $dy := ($kerning.y * $scale).round;
                    if $dx || $dy {
                        @shaped.push: $!encoder.encode-cids: @cids;
                        @cids = ();
                        @shaped.push: Complex.new(-$dx, $dy);
                        $width += $dx;
                    }
                }
                @cids.push: $cid;
                $prev-gid = $this-gid;
            }
        }

        @shaped.push: $!encoder.encode-cids: @cids
            if @cids;
    }
    else {
        @shaped.push: $!encoder.encode: $text;
        $width = self.stringwidth($text);
    }

    @shaped, $width;
}

method !make-subset {
    # perform subsetting on the font
    my %ords := $!encoder.charset;
    my $buf := $!font-buf;
    my %input = do if $!enc ~~ m/^[identity|utf]/ {
        # need to retain gids for identity based encodings
        my @glyphs = %ords.values;
        %( :@glyphs, :retain-gids)
    }
    else {
        my @unicodes = %ords.keys;
        %( :@unicodes );
    }
    my $subset = subsetter().new: :%input, :face{ :$buf };
    $subset.Blob;
}

method cb-finish {
    my $dict := self.to-dict;

    $!encoder.protect: {
        if $.first-char.defined {
            my $widths-updated = $!encoder.widths-updated;
            my $encoding-updated = $!encoder.encoding-updated;

            if !$!finished || $widths-updated || $encoding-updated {
                my $save-widths := $!build-widths && $widths-updated--;
                my $save-gids   := $!gids-updated--;
                self.finish-font: $dict, :$save-widths, :$save-gids;
                if $!subset {
                    my PDF::COS::Stream $font-file = self!make-font-file: self!make-subset();
                    $!font-descriptor{self!font-file-entry} = $font-file;
                }
                $!finished = True;
            }
        }
        else {
            warn "Font not used: $!font-name";
        }
    }
    $dict;
}

## Informational methods
method type { $.to-dict<Subtype>.fmt; }
method is-embedded {
    do with $!font-descriptor {
        .{self!font-file-entry}:exists;
    } || False;
}
method is-subset { so ($!font-name ~~ m/^<[A..Z]>**6"+"/) }
method is-core-font { self.type ~~ 'Type1' && ! self.font-descriptor.defined && PDF::Content::Font::CoreFont.core-font-name($!font-name).defined }

=begin pod
=head2 Methods

### font-name

The font name

### height

Overall font height

### encode

Encodes strings

### decode

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

Produces a draft PDF font dictionary. cb-finish() needs to be called to finalize it.

=head3 cb-finish

Finishing hook for the PDF tool-chain. This produces a finalized PDF font dictionary, including embedded fonts, character widths and encoding mappings.

=head3 is-embedded

Whether a font-file is embedded.

=head3 is-subset

Whether the font has been subsetting

=head3 is-core-font

Whether the font is a core font

=head3 has-encoding

Whether the font has unicode encoding. This is needed to encode or extract text.

=head3 underline-position

Position, from the baseline where an underline should be drawn. This is usually
negative and should be multipled by the font-size/1000 to get the actual position.

=head3 underline-thickness

Recommended underline thickness for the font. This should be multipled by font-size/1000.

=head3 face

L<Font::FreeType::Face> object associated with the font.

If the font was loaded from a `$dict` object and `is-embedded` is true, the `face` object has been loaded from the embedded font, otherwise its a system-loaded
font, selected to match the font.

=head3 stringwidth
=begin code :lang<raku>
method stringwidth(Str $text, Numeric $point-size?, Bool :$kern) returns Numeric
=end code
Returns the width of the string passed as argument.

By default the computed size is in 1000's of a font unit. Alternatively second `point-size` argument can be used to scale the width according to the font size.

The `:kern` option can be used to adjust the stringwidth, using the font's horizontal kerning tables.

=head3 get-glyphs
=begin code :lang<raku>
use PDF::Font::Loader::Glyph;
my PDF::Font::Loader::Glyph @glyphs = $font.get-glyphs: "Hi";
say "name:{.name} code:{.code-point} cid:{.cid} gid:{.gid} dx:{.dx} dy:{.dy}"
    for @glyphs;
=end code

Maps a string to glyphs, of type L<PDF::Font::Loader::Glyph>.

=end pod
