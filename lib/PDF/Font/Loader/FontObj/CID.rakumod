use PDF::Font::Loader::FontObj :FontFlags;

unit class PDF::Font::Loader::FontObj::CID
    is PDF::Font::Loader::FontObj;

use PDF::COS::Name;
use PDF::IO::Util :pack;
use PDF::IO::Writer;
use PDF::COS::Stream;

sub prefix:</>($name) { PDF::COS::Name.COERCE($name) };

sub charset-to-unicode(%charset) {
    my uint32 @to-unicode;
    @to-unicode[.value] = .key
        for %charset.pairs;
    @to-unicode;

}

submethod TWEAK {
    if self.encoding.starts-with('Identity') {
        die "can't use {self.encoding} encoding with unembedded font {self.font-name}"
            unless self.is-embedded;
    }
}

method !cid-font-type-entry {
    given $.face.font-format {
        when 'CFF' { 'CIDFontType0' }
        when 'TrueType'|'OpenType'    {'CIDFontType2'}
        default { fail "unable to handle CID font type: $_" }
    }
}

method !make-cmap-widths {
    my @W;
    my uint $j = -2;
    my $chars = [];
    my uint16 $n = $.last-char - $.first-char;
    loop (my uint16 $i = 0; $i <= $n; $i++) {
        my uint $w = @.widths[$i];
        if $w {
            if ++$j == $i {
                $chars.push: $w;
            }
            else {
                $chars = $w.Array;
                $j = $i;
                @W.append: ($i + $.first-char, $chars);
            }
        }
    }
    @W;
}

method !make-cmap-stream {
    my PDF::COS::Name $CMapName .= COERCE: 'raku-cmap-' ~ $.font-name;
    my PDF::COS::Name $Type .= COERCE: 'CMap';

    my $dict = %(
        :$Type,
        :$CMapName,
        :CIDSystemInfo{
            :Ordering<Identity>,
            :Registry($.font-name),
            :Supplement(0),
        },
    );

    my $to-unicode := $.subset
        ?? charset-to-unicode($.encoder.charset)
        !! $.encoder.to-unicode;
    my @cmap-char;
    my @cmap-range;
    my \i = $.encoder.bytes-per-cid - 1;
    my \cid-fmt   := ('<%02X>', '<%04X>')[i];
    my \char-fmt  := ('<%02X> <%04X>', '<%04X> <%04X>')[i];
    my \range-fmt := ('<%02X> <%02X> <%04X>', '<%04X> <%04X> <%04X>')[i];
    my \last-char := $.last-char;

    loop (my uint16 $cid = $.first-char; $cid <= last-char; $cid++) {
        my uint32 $char-code = $to-unicode[$cid]
          || next;
        my uint16 $start-cid = $cid;
        my uint32 $start-code = $char-code;
        while $cid < last-char && $to-unicode[$cid + 1] == $char-code+1 {
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
    my $postscript-name = $writer.write: :literal($.font-name);

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
        1 begincodespacerange {$.first-char.fmt(cid-fmt)} {last-char.fmt(cid-fmt)} endcodespacerange
        {@cmap-char.join: "\n"}
        {@cmap-range.join: "\n"}
        endcmap CMapName currendict /CMap defineresource pop end end
        --END--

    PDF::COS::Stream.COERCE: { :$dict, :$decoded };
}

method !make-gid-map {
    my $cids = $.encoder.cid-to-gid-map;
    my $decoded = unpack($cids, 16);
    PDF::COS::Stream.COERCE: { :$decoded };
}

method finish-font($dict, :$save-widths, :$save-gids) {
    $dict<ToUnicode> //= self!make-cmap-stream;

    $dict<DescendantFonts>[0]<W> = self!make-cmap-widths
        if $save-widths;
            
    $dict<CIDToGIDMap> = self!make-gid-map
        if $save-gids;    
}

method make-dict {
    my $BaseFont = /($.font-name);
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

    with self.font-descriptor {
        .<Flags> +|= FontFlags::Symbolic;
        $DescendantFonts[0]<dict><FontDescriptor> = $_;
    }

    my $Encoding = /(self.encoding);
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
