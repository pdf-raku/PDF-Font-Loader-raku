use PDF::Content::FontObj;

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
use PDF::Font::Loader::Enc::Identity8;
use PDF::Font::Loader::Enc::Identity16;
use PDF::Font::Loader::Enc::Type1;
use PDF::Font::Loader::Enc::Glyphic;
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

has Font::FreeType::Face:D $.face is required;
use PDF::Font::Loader::Enc;
has PDF::Font::Loader::Enc $!encoder handles <decode first-char last-char widths>;
method encoder { $!encoder }
has Blob $.font-buf;
has PDF::COS::Dict $!dict;
# Font descriptors are needed for all but core fonts
has $.font-descriptor = PDF::COS::Dict.COERCE: %( :Type(/'FontDescriptor'));
my subset EncodingScheme where 'mac'|'win'|'zapf'|'sym'|'identity'|'identity-h'|'identity-v'|'std'|'mac-extra'|'cmap';
has EncodingScheme $.enc;
has Bool $.embed = True;
has Bool $.subset = False;
has Str:D $.family          = $!face.family-name;
has Str:D $.font-name is rw = $!face.postscript-name // $!family;
has Bool $!finished;
has Bool $!gids-updated;
has Bool $!build-widths;
my constant Glyph = PDF::Font::Loader::Glyph;
has Glyph %!glyphs{Int};

sub subsetter {
    require ::("HarfBuzz::Subset")
}

submethod TWEAK(
    EncodingScheme:D :$!enc!,
    PDF::COS::Dict :$!dict,
    :@cid-to-gid-map,
    :@differences,
    :%encoder,
) {

    $!subset = False
        unless $!embed;

    if $!subset && (try subsetter()) === Nil {
        warn "HarfBuzz::Subset is required for font subsetting";
        $!subset = False;
    }

    if $!embed
    && self!font-type-entry eq 'TrueType'
    && $!font-buf.subbuf(0,4).decode('latin-1') eq 'ttcf' {
        # Its a TrueType collection which is not directly supported as a format,
        # however, HarfBuzz::Subset will convert it for us.
        unless $!subset {
            warn "unable to embed TrueType Collections font $!font-name without subsetting";
            $!embed = False;
        }
    }

    if $!subset {
        if $!face.font-format ~~ 'TrueType'|'OpenType'|'CFF' {
            $!font-name ~~ s/^[<[A..Z]>**6"+"]?/{(("A".."Z").pick xx 6).join ~ "+"}/;
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
        when %encoder<cmap>.defined {
            PDF::Font::Loader::Enc::CMap.new: :$!face, |%encoder, :@cid-to-gid-map;
        }
        when $!enc eq 'identity' {
            PDF::Font::Loader::Enc::Identity8.new: :$!face, |%encoder;
        }
        when $!enc ~~ 'identity-h'|'identity-v' {
            PDF::Font::Loader::Enc::Identity16.new: :$!face, |%encoder;
        }
        default {
            PDF::Font::Loader::Enc::Type1.new: :$!enc, :$!face, |%encoder, :@cid-to-gid-map;
        }
    }

    $!encoder.differences = @differences
        if @differences;
    # Be careful not to start adding widths if an existing
    # font dictionary doesn't already have them.
    $!build-widths = %encoder<widths>.so || !$!dict.defined;
    $!finished = ! $!build-widths;

    PDF::Content::Font.make-font($_, self)
        with $!dict;
}

method load-font(|c) {
    (require ::('PDF::Font::Loader')).load-font: |c;
}

method height($pointsize = 1000, Bool :$from-baseline, Bool :$hanging) {
    die "todo: height of non-scaling fonts" unless $!face.is-scalable;
    my FT_BBox $bbox = $!face.bounding-box;
    my Numeric $height = $hanging ?? $!face.ascender !! $bbox.y-max;
    $height -= $hanging ?? $!face.descender !! $bbox.y-min
        unless $from-baseline;
    $height * $pointsize /($!face.units-per-EM);
}

method glyph-width(Str $ch) is rw {
    Proxy.new(
        FETCH => { .dx with self.glyphs($ch)[0] },
        STORE => -> $, UInt() $width {
            with $!encoder.encode($ch, :cids)[0] -> $cid {
                $!encoder.set-width($cid, $width);
                self!glyph($cid).dx = $width;
            }
        }
    );
}

multi method stringwidth(Str $text, :$kern) {
    ([+] $!encoder.encode($text, :cids).map: { self!glyph($_).dx })
    + ($kern ?? self!font-kerning($text)[Width] !! 0);
}
multi method stringwidth(Str $text, $pointsize, :$kern) {
    self.stringwidth($text, :$kern) * $pointsize / 1000;
}

method decode-cids(Str $byte-str) {
    my @cids = $!encoder.decode($byte-str, :cids);
    if $!build-widths || $!encoder.cid-to-gid-map {
        self!glyph($_) for @cids;
    }
    @cids;
}

method encode($text is raw, |c) {
    if $!build-widths || $!encoder.cid-to-gid-map {
        self!glyph($_) for $!encoder.encode($text, :cids);
    }
    $!encoder.encode($text, |c);
}
method !font-type-entry returns Str {
    given $!face.font-format {
        when 'Type 1'|'CFF' {'Type1' }
        when 'TrueType'|'OpenType' { 'TrueType' }
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
    my PDF::Font::Loader::Type1::Stream $stream .= new: :$buf;
    my $Length1 = $stream.length[0];
    my $Length2 = $stream.length[1];
    my $Length3 = $stream.length[2];
    my PDF::IO::Blob $encoded .= COERCE: $buf;

    PDF::COS::Stream.COERCE: {
        :$encoded,
        :dict{
            :$Length1, :$Length2, :$Length3,
        },
    }
}

method !make-other-font-file($buf) {
    my $decoded = PDF::IO::Blob.new: $buf;

    my %dict = :Length1($buf.bytes);
    %dict<Filter> = /<FlateDecode>;

    given $!face.font-format {
        when 'OpenType' {
            %dict<Subtype> = /<CIDFontType0C>;
        }
        when 'CFF' {
            %dict<Subtype> = /<Type1C>;
        }
    }

    PDF::COS::Stream.COERCE: { :$decoded, :%dict, };
}

method !make-font-file($buf) {
    $!face.font-format eq 'Type 1'
        ?? self!make-type1-font-file($buf)
        !! self!make-other-font-file($buf);
}

method !glyph($cid is raw) {
    %!glyphs{$cid} //= $!encoder.glyph($cid);
}

multi method glyphs(Str:D $text) {
    self.glyphs: $!encoder.encode($text, :cids);
}
multi method glyphs(@cids) {
    @cids.map: { self!glyph($_); };
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

        # set up required fields
        my UInt $CapHeight  = do with $tt-pclt { .capHeight }
            else { (self!char-height( 'X'.ord) || $Ascent * 0.9).round };
        my UInt $XHeight    = do with $tt-pclt { .xHeight }
            else { (self!char-height( 'x'.ord) || $Ascent * 0.7).round };
        my Int $ItalicAngle = do with $tt-post { .italicAngle.round }
        else { $!face.is-italic ?? -12 !! 0 };

        my $FontName  = /($!font-name);
        my $FontFamily = /($!family);
        # google impoverished guess
        my UInt $StemV = $!face.is-bold ?? 110 !! 80;

        $dict.Hash ,= %(
            :$FontName, :$FontFamily, :$Flags,
            :$Ascent, :$Descent, :@FontBBox,
            :$ItalicAngle, :$StemV, :$CapHeight, :$XHeight,
        );

        # try for a few more properties

        with TT_OS2.load: :$!face {
            $dict<FontWeight> = .usWeightClass;
            $dict<AvgWidth> = .xAvgCharWidth;

            if $!face.font-format ~~ 'FreeType'|'OpenType' {
                # applicable to CID font descriptors
                my $buf = .panose.Blob;
                $buf.prepend: (.sFamilyClass div 256, .sFamilyClass mod 256);
                my $Panose = hex-string => $buf.decode: "latin-1";
                $dict<Style> = %( :$Panose );
            }
        }
        $dict<FontWeight> //= pclt-font-weight(.strokeWeight)
            with $tt-pclt;

        with TT_HoriHeader.load: :$!face {
            $dict<Leading>  = .lineGap;
            $dict<MaxWidth> = .advanceWidthMax;
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
    @to-unicode[.key] = .value
        for %charset.pairs;
    @to-unicode;
}

method make-cmap-stream {
    my PDF::COS::Name $CMapName .= COERCE: 'raku-cmap-' ~ $!font-name;
    my PDF::COS::Name $Type .= COERCE: 'CMap';

    my $dict = %(
        :$Type,
        :$CMapName,
        :CIDSystemInfo{
            :Ordering<Identity>,
            :Registry($!font-name),
            :Supplement(0),
        },
    );

    my $to-unicode := $!subset
        ?? charset-to-unicode($!encoder.charset)
        !! $!encoder.to-unicode;

    $!encoder.make-cmap-stream: :$dict, :$to-unicode, :$.font-name;
}

# finalize the font, depending on how it's been used
method finish-font($dict, :$save-widths) {
    $dict<ToUnicode> //= self.make-cmap-stream
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
                unless $_ eq 'StandardEncoding'; # implied anyway
        }

        $dict<Encoding> = %enc;
    }
}

method make-dict {
    my $Type = /(<Font>);
    my $Subtype  = /(self!font-type-entry);
    my $BaseFont = /($!font-name);
    my $Encoding = /(self.encoding);

    my $dict = PDF::COS::Dict.COERCE: %(
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

method to-dict { $!dict //= PDF::Content::Font.make-font(self.make-dict, self) }

method !font-kerning(Str $text is copy) {
    my FT_UInt $prev-idx = 0;
    my FT_Vector $kerning .= new;
    my $struct = $!face.raw;
    my int $width = 0;
    my int $height = 0;
    my $scale = 1000 / ($!face.units-per-EM || 1000);

    for $text.ords -> $char-code {
        my FT_UInt $this-idx = $struct.FT_Get_Char_Index( $char-code );
        if $this-idx {
            if $prev-idx {
                ft-try({ $struct.FT_Get_Kerning($prev-idx, $this-idx, FT_KERNING_UNSCALED, $kerning); });
                $width  += $kerning.x;
                $height += $kerning.y;
            }
        }
        $prev-idx = $this-idx;
    }
    (($width * $scale).round, ($height * $scale).round);
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
        my FT_UInt      $prev-idx = 0;
        my FT_Vector    $kerning .= new;
        my FT_Face      $face-struct = $!face.raw;
        my FT_GlyphSlot $glyph-slot = $face-struct.glyph;
        my Str          $str = '';
        my $scale = 1000 / $!face.units-per-EM;

        for $text.ords -> $char-code {
            my FT_UInt $this-idx = $face-struct.FT_Get_Char_Index( $char-code );
            if $this-idx {
                if $prev-idx {
                    ft-try({ $face-struct.FT_Get_Kerning($prev-idx, $this-idx, FT_KERNING_UNSCALED, $kerning); });
                    my $dx := ($kerning.x * $scale).round;
                    if $dx {
                        @chunks.push: $str;
                        @chunks.push: $dx;
                        $kernwidth += $dx;
                        $str = '';
                    }
                }
                $str ~= $char-code.chr;
                $prev-idx = $this-idx;
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

method !make-subset {
    # perform subsetting on the font
    my %ords := $!encoder.charset;
    my $buf := $!font-buf;
    my %input = do if $!enc.starts-with('identity') {
        # need to retain gids for identity based encodings
        my @glyphs = %ords.keys;
        %( :@glyphs, :retain-gids)
    }
    else {
        my @unicodes = %ords.values;
        %( :@unicodes );
    }
    my $subset = subsetter().new: :%input, :face{ :$buf };
    $subset.Blob;
}

method cb-finish {
    my $dict := self.to-dict;
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
    $dict;
}

## Informational methods
method type { $.to-dict<Subtype>.fmt; }
method is-embedded {
    $!embed || do with $!font-descriptor {
        .{self!font-file-entry}:exists;
    } || False;
}
method is-subset { so ($!font-name ~~ m/^<[A..Z]>**6"+"/) }
method is-core-font { ! self.font-descriptor.defined }
method has-encoding {
    so $!encoder.to-unicode.first: {$_}
}

