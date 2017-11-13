class PDF::Font::TrueType {
    use PDF::DAO;
    use PDF::IO::Blob;
    use PDF::Content::Font::Enc::Type1;
    use PDF::Font::Enc::Identity-H;
    use Font::FreeType;
    use Font::FreeType::Face;
    use Font::FreeType::Error;
    use Font::FreeType::Native;
    use Font::FreeType::Native::Types;
    use PDF::Writer;

    constant Px = 64.0;

    has Font::FreeType::Face $.face;
    has $!encoder handles <decode>;
    has Blob $.font-stream is required;
    use PDF::Content::Font;
    has PDF::Content::Font $!dict;
    has uint16 $!first-char;
    has uint16 $!last-char;
    has uint16 @!widths;
    my subset EncodingScheme of Str where 'mac'|'win'|'identity-h';
    has EncodingScheme $!enc;

    submethod TWEAK(:$!enc = 'identity-h') {
        $!encoder = $!enc eq 'identity-h'
                ?? PDF::Font::Enc::Identity-H.new: :$!face
                !! PDF::Content::Font::Enc::Type1.new: :$!enc;
        @!widths[255] = 0;
    }

    method height($pointsize, Bool :$from-baseline) {
        die "todo: non-scaling fonts" unless $!face.is-scalable;
        my $height = $!face.ascender;
        $height -= $!face.descender unless $from-baseline;
        $height / ($pointsize * Px);
    }

    method encode(Str $text, :$str) {
        my buf8 $encoded = $!encoder.encode($text);
        my $to-unicode := $!encoder.to-unicode;
        my $min = $encoded.min;
        my $max = $encoded.max;
        $!first-char = $min if !$!first-char || $min < $!first-char;
        $!last-char = $max if !$!last-char || $max > $!last-char;
        for $encoded.list {
            @!widths[$_] ||= $.stringwidth($to-unicode[$_].chr).round;
        }

        $str
            ?? $encoded.decode('latin-1')
            !! $encoded;
    }

    method !font-descriptor {
        my $Ascent = $!face.ascender;
        my $Descent = $!face.descender;
        my $FontName = PDF::DAO.coerce: :name($!face.postscript-name);
        my $FontFamily = $!face.family-name;
        my $FontBBox = $!face.bounding-box.Array;
        my $decoded = PDF::IO::Blob.new: $!font-stream;
        my $FontFile2 = PDF::DAO.coerce: :stream{
            :$decoded,
            :dict{
                :Length1($!font-stream.bytes),
                :Filter( :name<FlateDecode> ),
            },
        };

        my $dict = {
            :Type( :name<FontDescriptor> ),
            :$FontName, :$FontFamily, :$Ascent, :$Descent, :$FontBBox, :$FontFile2,
        };
    }

    method !make-roman-dict {
        my %enc-name = :win<WinAnsiEncoding>, :mac<MacRomanEncoding>;
        my $FontDescriptor = self!font-descriptor;
        my $BaseFont = $FontDescriptor<FontName>;
        my $dict = { :Type( :name<Font> ), :Subtype( :name<TrueType> ),
                     :$BaseFont,
                     :$FontDescriptor,
                 };

        with %enc-name{$!enc} -> $name {
            $dict<Encoding> = :$name;
        }
        $dict;
    }

    method !unicode-cmap {
        my $dict = {
            :Type( :name<CMap> ),
              :CIDSystemInfo{
                  :Ordering<Identity>,
                    :Registry($!face.postscript-name),
                    :Supplement(0),
                },
        };

        my $to-unicode := $!encoder.to-unicode;
        my @cmap;

        for $!first-char .. $!last-char -> int $cid {
            my $char-code = $to-unicode[$cid]
              || next;
            @cmap.push: '<%04X> <%04X> <%04X>'.sprintf($cid, $cid, $char-code);
        }

        my $postscript-name = PDF::Writer.new.write: :literal($!face.postscript-name);
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
            /CMapName /pdfapi2-BiCBA+0 def
            1 begincodespacerange <{$!first-char.fmt("%04x")}> <{$!last-char.fmt("%04x")}> endcodespacerange
            {+@cmap} beginbfrange
            {@cmap.join: "\n"}
            endbfrange
            endcmap CMapName currendict /CMap defineresource pop end end
            --END--



        PDF::DAO.coerce: :stream{ :$dict, :$decoded };
    }

    method !make-index-dict {
        my $FontDescriptor = self!font-descriptor;
        my $BaseFont = $FontDescriptor<FontName>;
        my $DescendantFonts = [
            :dict{
                :Type( :name<Font> ),
                  :Subtype( :name<CIDFontType2> ),
                  :$BaseFont,
                  :CIDToGIDMap( :name<Identity> ),
                  :CIDSystemInfo{
                      :Ordering<Identity>,
                        :Registry<Adobe>,
                        :Supplement(0),
                    },
                    :$FontDescriptor,
                }
           ];

        { :Type( :name<Font> ), :Subtype( :name<Type0> ),
            :$BaseFont,
            :$DescendantFonts,
            :Encoding( :name<Identity-H> ),
        };
    }

    method !make-dict {
        $!enc eq 'identity-h'
          ?? self!make-index-dict
          !! self!make-roman-dict
      }

    method to-dict {
        $!dict //= PDF::Content::Font.make-font(
            PDF::DAO::Dict.coerce(self!make-dict),
            self);
    }

    method stringwidth(Str $str is copy, $pointsize = 1000, Bool :$kern=False) {
        $str = 'i' if $str eq ' '; # hack
        $!face.set-char-size($pointsize, $pointsize, 72, 72);
        my $vec = $!face.measure-text( $str, :$kern);
        $vec.x;
    }

    method kern(Str $text, Numeric $pointsize?) {
        my FT_Pos $x = 0;
        my FT_Pos $y = 0;
        my FT_UInt $prev-idx = 0;
        my $kerning = FT_Vector.new;
        my $face-struct = $!face.struct;
        my $glyph-slot = $face-struct.glyph;
        my $str = '';
        my @chunks;
        my Numeric $stringwidth = 0.0;

        for $text.ords -> $char-code {
            my FT_UInt $this-idx =  $face-struct.FT_Get_Char_Index( $char-code );
            if $this-idx {
                ft-try({ $face-struct.FT_Load_Glyph( $this-idx, FT_LOAD_NO_SCALE); });
                $stringwidth += $glyph-slot.metrics.hori-advance;
                if $prev-idx {
                    ft-try({ $face-struct.FT_Get_Kerning($prev-idx, $this-idx, FT_KERNING_UNSCALED, $kerning); });
                    my $dx = $kerning.x;
                    unless $dx =~= 0 {
                        $stringwidth += $dx;
                        @chunks.push: $str;
                        $dx *= $pointsize / 1000
                            if $pointsize;
                        @chunks.push: $dx;
                        $str = '';
                    }
                }
                $str ~= $char-code.chr;
                $prev-idx = $this-idx;
            }
        }

        @chunks.push: $str
            if $str.chars;

        $stringwidth *= $pointsize / 1000
            if $pointsize;

        @chunks, $stringwidth;
    }

    method cb-finish {
        given $!enc {
            when 'identity-h' {
                my @Widths;
                my int $j = -2;
                my $chars = [];
                loop (my int $i = $!first-char; $i <= $!last-char; $i++) {
                    my int $w = @!widths[$i];
                    if $w {
                        if ++$j == $i {
                            $chars.push: $w;
                        }
                        else {
                            $chars = [ $w, ];
                            $j = $i;
                            @Widths.append: ($i, $chars);
                        }
                    }
                }
                $.to-dict<DescendantFonts>[0]<W> = @Widths;
                $.to-dict<ToUnicode> = self!unicode-cmap;
            }
            default {
                given $.to-dict {
                    .<FirstChar> = $!first-char;
                    .<LastChar> = $!last-char;
                    .<Widths> = @!widths[$!first-char .. $!last-char];
                }
            }
        }
    }
}
