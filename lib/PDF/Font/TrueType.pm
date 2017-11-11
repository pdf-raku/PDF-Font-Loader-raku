class PDF::Font::TrueType {
    use PDF::DAO;
    use PDF::IO::Blob;
    use PDF::Content::Font::Enc::Type1;
    use PDF::Font::Enc::Identity-H;
    use Font::FreeType;
    use Font::FreeType::Face;

    has Font::FreeType::Face $.face;
    has $!encoder handles <decode>;
    has Blob $.font-stream is required;
    use PDF::Content::Font;
    has PDF::Content::Font $!dict;
    has Int $!first-char;
    has Int $!last-char;
    has int16 @!widths;
    my subset EncodingScheme of Str where 'mac'|'win'|'identity-h';
    has EncodingScheme $!enc;

    submethod TWEAK(:$!enc = 'identity-h') {
        $!encoder = $!enc eq 'identity-h'
                ?? PDF::Font::Enc::Identity-H.new: :$!face
                !! PDF::Content::Font::Enc::Type1.new: :$!enc;
        @!widths[255] = 0;
    }

    method encode(Str $text, :$str) {
        my buf8 $encoded = $!encoder.encode($text);
        unless $!enc eq 'identity-h' {
            my $to-unicode := $!encoder.to-unicode;
            my $min = $encoded.min;
            my $max = $encoded.max;
            $!first-char = $min if !$!first-char || $min < $!first-char;
            $!last-char = $max if !$!last-char || $max > $!last-char;
            for $encoded.list {
                @!widths[$_] ||= $.stringwidth($to-unicode[$_].chr).round;
            }
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

      method !make-index-dict {
          my %enc-name = :win<WinAnsiEncoding>, :mac<MacRomanEncoding>, :identity-h<Identity-H>;
          my $FontDescriptor = self!font-descriptor;
          my $BaseFont = $FontDescriptor<FontName>;
          my $DescendantFonts = [
              :dict{
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
          my $dict = { :Type( :name<Font> ), :Subtype( :name<Type0> ),
                       :$BaseFont,
                       :$DescendantFonts,
                       :Encoding( :name<Identity-H> ),
                   };

          with %enc-name{$!enc} -> $name {
              $dict<Encoding> = :$name;
          }

          $dict;
      }

      method !make-dict {
          $!enc eq 'identity-h'
            ?? self!make-index-dict
            !! self!make-roman-dict
      }

      method to-dict {
        $!dict //=  PDF::Content::Font.make-font(
                PDF::DAO::Dict.coerce(self!make-dict),
                self);

    }

    multi method stringwidth(Str $str is copy, $pointsize = 1000, Bool :$kern=False) {
        $str = 'i' if $str eq ' '; # hack
        $!face.set-char-size($pointsize, $pointsize, 72, 72);
        my $vec = $!face.measure-text( $str, :$kern);
        $vec.x;
    }

    method cb-finish {

        unless $!enc eq 'identity-h' {
            warn "FINISH";
            given $.to-dict {
                .<FirstChar> = $!first-char;
                .<LastChar> = $!last-char;
                .<Widths> = @!widths[$!first-char .. $!last-char];
            }
        }
    }
}
