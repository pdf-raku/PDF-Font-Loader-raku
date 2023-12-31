#| /Identity-H or /Identity-V encoded fonts
use PDF::Font::Loader::Enc;
class PDF::Font::Loader::Enc::Identity16
    is PDF::Font::Loader::Enc {

use PDF::Content::Font::Encoder;
also does PDF::Content::Font::Encoder;

    use Font::FreeType::Face;
    use Font::FreeType::Raw;
    use Font::FreeType::Raw::Defs;
    use PDF::COS;
    use PDF::IO::Util :&pack;

    has Font::FreeType::Face $.face is required;
    has FT_Face $!raw;
    has uint32 @!to-unicode;
    has UInt %.charset{UInt};
    has UInt $.min-index;
    has UInt $.max-index;
    has atomicint $!init = 0;

    submethod TWEAK {
        $!raw = $!face.raw;
    }

    method is-wide {True}

    method set-encoding($ord, $cid) {
        @!to-unicode[$cid] ||= $ord;
        %!charset{$ord} ||= $cid;        
        $cid;
    }

    method add-encoding(UInt:D $ord) {
        self.set-encoding: $ord, $!raw.FT_Get_Char_Index($ord);
    }

    multi method encode(Str $text, :cids($)!) {
        $.lock.protect: {
            blob16.new: $text.ords.map: -> $ord {
                self.add-encoding($ord);
            }
        }
    }

    method encode-cids(@cids is raw) {
        my blob8 $buf := pack(@cids, 16);
        $buf.decode: 'latin-1';
    }

    multi method encode(Str $text --> Str) {
        self.encode-cids: self.encode($text, :cids);
    }

    method !setup-decoding {
        $.lock.protect: {
            unless $!init {
                my FT_Face $struct = $!face.raw;
                my FT_UInt $glyph-idx;
                my FT_ULong $char-code = $struct.FT_Get_First_Char( $glyph-idx);
                @!to-unicode[$!face.num-glyphs] = 0;
                while $glyph-idx {
                    @!to-unicode[ $glyph-idx ] = $char-code;
                    $char-code = $struct.FT_Get_Next_Char( $char-code, $glyph-idx);
                }
                $!init ⚛= 1;
            }
        }
    }

    method to-unicode {
        $!init || self!setup-decoding();
        @!to-unicode;
    }

    multi method decode(Str $encoded, :cids($)!) {
        $encoded.ords.map: -> \hi, \lo {hi +< 8 + lo};
    }

    multi method decode(Str $encoded, :ords($)!) {
        my @to-unicode := self.to-unicode;
        $.lock.protect: {self.decode($encoded, :cids).map({@to-unicode[$_] || Empty})};
    }

    multi method decode(Str $encoded --> Str) {
        $.decode($encoded, :ords)».chr.join;
    }
}

=begin pod

=head2 Description

This class implements`Identity-H` and `Identity-V` encoding.

This is common 2 byte encoding that directly encodes font glyph identifiers as
CIDs. It was introduced with PDF 1.3.

=end pod
