use PDF::Content::FontObj;

class PDF::Font::Loader::FontObj
    does PDF::Content::FontObj {
    use PDF::COS;
    use PDF::COS::Dict;
    use PDF::COS::Name;
    use PDF::COS::Stream;
    use PDF::IO::Blob;
    use PDF::IO::Writer;
    use PDF::IO::Util :pack;
    use NativeCall;
    use PDF::Font::Loader::Enc::CMap;
    use PDF::Font::Loader::Enc::Identity8;
    use PDF::Font::Loader::Enc::Identity16;
    use PDF::Font::Loader::Enc::Type1;
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

    has Font::FreeType::Face:D $.face is required;
    use PDF::Font::Loader::Enc;
    has PDF::Font::Loader::Enc $!encoder handles <decode enc>;
    has Blob $.font-buf;
    has PDF::COS::Dict $!dict;
    # Font descriptors are needed for all but core fonts
    has $.font-descriptor = PDF::COS::Dict.COERCE: %( :Type(/'FontDescriptor'));
    has uint $.first-char;
    has uint $.last-char;
    has uint16 @!widths;
    method widths is rw { @!widths }
    my subset EncodingScheme where 'mac'|'win'|'zapf'|'sym'|'identity'|'identity-h'|'identity-v'|'std'|'mac-extra';
    has EncodingScheme $!enc;
    has Bool $.embed = True;
    has Bool $.subset = False;
    has Str:D $.family          = $!face.family-name;
    has Str:D $.font-name is rw = $!face.postscript-name // $!family;
    has Bool $!finished = True;
    has Bool $!add-widths;

    sub subsetter {
        require ::("HarfBuzz::Subset")
    }

    submethod TWEAK(
        PDF::COS::Dict :$!dict,
        :@differences,
        :$widths,
        PDF::COS::Stream :$cmap,
        Str :$!enc = self!font-type-entry eq 'Type1' || !$!embed || $!face.num-glyphs <= 255
            ?? 'win'
            !! 'identity-h',
    ) is hidden-from-backtrace {

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
            if self!font-type-entry eq 'TrueType' {
                $!font-name ~~ s/^[<[A..Z]>**6"+"]?/{(("A".."Z").pick xx 6).join ~ "+"}/;
            }
            else {
               warn  "unable to subset font $!font-name of type {$!face.font-type}";
               $!subset = False;
            }
        }

        $!encoder = do {
            when $cmap.defined {
                PDF::Font::Loader::Enc::CMap.new: :$cmap, :$!face;
            }
            when $!enc eq 'identity' {
                PDF::Font::Loader::Enc::Identity8.new: :$!face;
            }
            when $!enc ~~ 'identity-h'|'identity-v' {
                PDF::Font::Loader::Enc::Identity16.new: :$!face;
            }
            default {
                PDF::Font::Loader::Enc::Type1.new: :$!enc, :$!face;
            }
        }

        $!encoder.differences = @differences
            if @differences;

        @!widths = .map(*.Int) with $widths;
        # Be careful not to start adding widths if an existing
        # font dictionary doesn't already have them.
        $!add-widths = so @!widths || !$!dict.defined;

        PDF::Content::Font.make-font($_, self)
            with $!dict;
    }

    method height($pointsize = 1000, Bool :$from-baseline, Bool :$hanging) {
        die "todo: height of non-scaling fonts" unless $!face.is-scalable;
        my FT_BBox $bbox = $!face.bounding-box;
        my Numeric $height = $hanging ?? $!face.ascender !! $bbox.y-max;
        $height -= $hanging ?? $!face.descender !! $bbox.y-min
            unless $from-baseline;
        $height * $pointsize /($!face.units-per-EM);
    }

    multi method stringwidth(Str $text, :$kern) {
        self.encode($text, :width)
        + ($kern ?? self!font-kernwidth($text) !! 0);
    }
    multi method stringwidth(Str $text, $pointsize, :$kern) {
        self.stringwidth($text, :$kern) * $pointsize / 1000;
    }

    method encode(Str $text, :$str, :$width) {
        my int $w = 0;
        my $encoded := $!encoder.encode($text);
        if $encoded {
            my $to-unicode := $!encoder.to-unicode;
            unless $!last-char {
                $!first-char = $encoded[0];
                $!last-char  = $encoded[0];
                @!widths = [0];
            }

            for $encoded.list {
                if $!first-char > $_ {
                    @!widths.prepend: 0 xx ($!first-char - $_);
                    $!first-char = $_;
                }
                $w += (
                    @!widths[$_ - $!first-char] ||= do {
                        $!finished = False;
                        self!font-stringwidth($to-unicode[$_].chr).round;
                    }
                );
            }
            $!last-char = $!first-char + @!widths - 1;

            if $width {
                $w;
            }
            else {
                # 16 bit encoding. convert to bytes
                $encoded := pack($encoded, 16)
                    if $encoded.of ~~ uint16;

                $str ?? $encoded.decode('latin-1') !! $encoded;
            }
        }
    }

    method glyph-width(Str $ch) is rw {
        if $!add-widths && self.encode($ch) {
            my $enc = $!encoder.encode($ch);
            @!widths[ $enc[0] - $!first-char ];
        }
        else {
            Numeric;
        }
    }

    method !font-type-entry returns Str {
        given $!face.font-format {
            when 'Type 1'|'CFF' {'Type1' }
            when 'TrueType'|'OpenType' { 'TrueType' }
            default { fail "unable to handle font type: $_" }
        }
    }

    method !cid-font-type-entry {
        given $!face.font-format {
            when 'Type1' {'Type1'}
            when 'CFF' { 'CIDFontType0' }
            when 'TrueType'|'OpenType'    {'CIDFontType2'}
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

    sub bit(\n) { 1 +< (n-1) }
    my enum Flags «
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

    sub pclt-font-weight(Int $w) {
        given ($w + 7) / 14 {
            when * < .1 { 100 }
            when * > .9 { 900 }
            default { .round(.1) * 100 }
        }
    }

    method !font-descriptor {

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

    method !encoding-name {

        constant %EncName = %(
            :win<WinAnsiEncoding>,
            :mac<MacRomanEncoding>,
            :mac-extra<MacExpertEncoding>,
            :identity-h<Identity-H>,
        );

        with %EncName{$!enc} {
            /($_);
        }
    }

    method !make-cmap-widths {
        my @W;
        my uint $j = -2;
        my $chars = [];
        my uint16 $n = $!last-char - $!first-char;
        loop (my uint16 $i = 0; $i <= $n; $i++) {
            my uint $w = @!widths[$i];
            if $w {
                if ++$j == $i {
                    $chars.push: $w;
                }
                else {
                    $chars = $w.Array;
                    $j = $i;
                    @W.append: ($i + $!first-char, $chars);
                }
            }
        }
        @W;
    }

    # finalize the font, depending on how it's been used
    method !finish-font($dict) {
        if $!enc.starts-with('identity') {
            $dict<DescendantFonts>[0]<W> = self!make-cmap-widths
                if $!add-widths;
            $dict<ToUnicode> //= self!make-cmap-stream;
        }
        else {
            if $!add-widths {
                $dict<FirstChar> = $!first-char;
                $dict<LastChar> = $!last-char;
                $dict<Widths> = @!widths;
            }
            if $!encoder.differences -> $Differences {
                $dict<Encoding> = %(
                    Type =>         /<Encoding>,
                    BaseEncoding => /(self!encoding-name),
                    :$Differences,
                )
            }
        }

        if $!subset {
            my Blob $buf = self!make-font-file: self!make-subset();
            $!font-descriptor{self!font-file-entry} = $buf;
        }
    }

    method !make-enc-dict {
        my $Type = /(<Font>);
        my $Subtype  = /(self!font-type-entry);
        my $BaseFont = /($!font-name);
        my $Encoding = /(self!encoding-name);

        my $dict = PDF::COS::Dict.COERCE: %(
            :$Type,
            :$Subtype,
            :$BaseFont,
            :$Encoding,
        );

        with self!font-descriptor {
            .<Flags> +|= Nonsymbolic;
            $dict.self<FontDescriptor> = $_;
        }

        $dict;
    }

    sub charset-to-unicode(%charset) {
        my uint32 @to-unicode;
        @to-unicode[.value] = .key
            for %charset.pairs;
        @to-unicode;

    }

    method !make-cmap-stream {
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
        my @cmap-char;
        my @cmap-range;
        my \cid-fmt = $!encoder.bytes-per-char == 1 ?? '<%02X>' !! '<%04X>';
        my \char-fmt := $!encoder.bytes-per-char == 1 ?? '<%02X> <%04X>' !! '<%04X> <%04X>';
        my \range-fmt := $!encoder.bytes-per-char == 1 ?? '<%02X> <%02X> <%04X>' !! '<%04X> <%04X> <%04X>';

        loop (my uint16 $cid = $!first-char; $cid <= $!last-char; $cid++) {
            my uint32 $char-code = $to-unicode[$cid]
              || next;
            my uint16 $start-cid = $cid;
            my uint32 $start-code = $char-code;
            while $cid < $!last-char && $to-unicode[$cid + 1] == $char-code+1 {
                $cid++; $char-code++;
            }
            if $start-cid == $cid {
                @cmap-char.push: char-fmt.sprintf($cid, $start-code);
            }
            else {
                @cmap-range.push: range-fmt.sprintf($start-cid, $cid, $start-code);
            }
        }

        if @cmap-char {
            @cmap-char.unshift: "{+@cmap-char} beginbfchar";
            @cmap-char.push: 'endbfchar';
        }

        if @cmap-range {
            @cmap-range.unshift: "{+@cmap-range} beginbfrange";
            @cmap-range.push: 'endbfrange';
        }

        my PDF::IO::Writer $writer .= new;
        my $cmap-name = $writer.write: $CMapName.content;
        my $postscript-name = $writer.write: :literal($!font-name);

        my $decoded = qq:to<--END-->.chomp;
            %% Custom
            %% CMap
            %%
            /CIDInit /ProcSet findresource begin
            12 dict begin begincmap
            /CIDSystemInfo <<
               /Registry $postscript-name
               /Ordering (XYZ)
               /Supplement 0
            >> def
            /CMapName $cmap-name def
            1 begincodespacerange {$!first-char.fmt(cid-fmt)} {$!last-char.fmt(cid-fmt)} endcodespacerange
            {@cmap-char.join: "\n"}
            {@cmap-range.join: "\n"}
            endcmap CMapName currendict /CMap defineresource pop end end
            --END--

        PDF::COS::Stream.COERCE: { :$dict, :$decoded };
    }

    method !make-cid-dict {
        my $BaseFont = /($!font-name);
        my $Type = /<Font>;
        my $Subtype = /(self!cid-font-type-entry);

        my $DescendantFonts = [
            :dict{
                :$Type,
                :$Subtype,
                :$BaseFont,
                :CIDToGIDMap( /<Identity> ),
                :CIDSystemInfo{
                    :Ordering<Identity>,
                      :Registry<Adobe>,
                      :Supplement(0),
                  },
            }, ];

        with self!font-descriptor {
            .<Flags> +|= Symbolic;
            $DescendantFonts[0]<dict><FontDescriptor> = $_;
        }

        my $Encoding = /($!enc eq 'identity-v' ?? 'Identity-V' !! 'Identity-H');
        my $dict = PDF::COS::Dict.COERCE: %(
            :Type( /<Font> ),
            :Subtype( /<Type0> ),
            :$BaseFont,
            :$DescendantFonts,
            :$Encoding,
        );
        $dict<DescendantFonts>[0].is-indirect = True;
        $dict;
    }

    method !make-dict {
        my @missing-atts = <bounding-box ascender descender>.grep: {!$!face."$_"().defined };
        die "font $!font-name (format {$!face.font-format}) lacks {@missing-atts.join: ', '} attributes; unable to proceed"
            if @missing-atts;

        if $!enc.starts-with('identity') {
            die "can't use $!enc encoding with unembedded font $!font-name"
                unless self.is-embedded;
            die "can't use $!enc encoding with type-1 font $!font-name"
                if self!font-type-entry eq 'Type1';
            self!make-cid-dict;
        }
        else {
            self!make-enc-dict;
        }
      }

    method to-dict { $!dict //= PDF::Content::Font.make-font(self!make-dict, self) }

    method !font-stringwidth(Str $text) {
        my FT_UInt $prev-idx = 0;
        my $struct = $!face.raw;
        my $glyph-slot = $struct.glyph;
        my Numeric $stringwidth = 0;
        my $scale = 1000 / ($!face.units-per-EM || 1000);

        for $text.ords -> $char-code {
            my FT_UInt $this-idx = $struct.FT_Get_Char_Index( $char-code );
            if $this-idx {
                CATCH {
                    when Font::FreeType::Error { warn "error processing char {$char-code.chr.raku} (code:$char-code, index:$this-idx): " ~ .message; }
                }
                ft-try({ $struct.FT_Load_Glyph( $this-idx, FT_LOAD_NO_SCALE ); });
                $stringwidth += $glyph-slot.metrics.hori-advance * $scale;
            }
            $prev-idx = $this-idx;
        }
        $stringwidth.round;
    }

    method !font-kernwidth(Str $text is copy) {
        my FT_UInt $prev-idx = 0;
        my FT_Vector $kerning .= new;
        my $struct = $!face.raw;
        my int $kernwidth = 0;
        my $scale = 1000 / ($!face.units-per-EM || 1000);

        for $text.ords -> $char-code {
            my FT_UInt $this-idx = $struct.FT_Get_Char_Index( $char-code );
            if $this-idx {
                if $prev-idx {
                    ft-try({ $struct.FT_Get_Kerning($prev-idx, $this-idx, FT_KERNING_UNSCALED, $kerning); });
                    my $dx := ($kerning.x * $scale).round;
                    $kernwidth += $dx;
                }
            }
            $prev-idx = $this-idx;
        }
        $kernwidth;
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
        my %input = do if $!enc.starts-with: 'identity' {
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
        if $!first-char.defined {
            unless $!finished {
                self!finish-font: $dict;
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
    method encoding { $!enc }
    method is-embedded {
        $!embed // do with $!font-descriptor {
            .{self!font-file-entry}:exists;
        } // False;
    }
    method is-subset { so ($!font-name ~~ m/^<[A..Z]>**6"+"/) }
    method is-core-font { ! self!font-descriptor.defined }

}

