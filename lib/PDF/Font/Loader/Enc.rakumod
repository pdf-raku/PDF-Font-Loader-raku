class PDF::Font::Loader::Enc {

    use PDF::COS::Name;
    use PDF::IO::Writer;
    use PDF::COS::Stream;

    method bpc { 1 }

    sub charset-to-unicode(%charset) {
        my uint32 @to-unicode;
        @to-unicode[.value] = .key
            for %charset.pairs;
        @to-unicode;

    }

    method cmap-stream(Str :$font-name!, Bool :$subset) {
        my PDF::COS::Name $CMapName .= COERCE('raku-cmap-' ~ $font-name);
        my PDF::COS::Name $Type .= COERCE: 'CMap';

        my $dict = %(
            :$Type,
            :$CMapName,
            :CIDSystemInfo{
                :Ordering<Identity>,
                :Registry($font-name),
                :Supplement(0),
            },
        );

        my $to-unicode := $subset
            ?? charset-to-unicode(self.charset)
            !! self.to-unicode;
        my @cmap-char;
        my @cmap-range;
        my \cid-fmt = self.bpc == 1 ?? '<%02X>' !! '<%04X>';
        my \char-fmt := self.bpc == 1 ?? '<%02X> <%04X>' !! '<%04X> <%04X>';
        my \range-fmt := self.bpc == 1 ?? '<%02X> <%02X> <%04X>' !! '<%04X> <%04X> <%04X>';
        my \first-char = self.first-char;
        my \last-char = self.last-char;

        loop (my uint16 $cid = first-char; $cid <= last-char; $cid++) {
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
        my $cmap-name = $writer.write: $CMapName;
        my $postscript-name = $writer.write: :literal($font-name);

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
            1 begincodespacerange {first-char.fmt(cid-fmt)} {last-char.fmt(cid-fmt)} endcodespacerange
            {@cmap-char.join: "\n"}
            {@cmap-range.join: "\n"}
            endcmap CMapName currendict /CMap defineresource pop end end
            --END--

        PDF::COS::Stream.COERCE: { :$dict, :$decoded };
    }
}
