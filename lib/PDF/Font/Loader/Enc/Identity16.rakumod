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
    has UInt %.charset{UInt};
    has UInt $.min-index;
    has UInt $.max-index;
    has uint32 @.to-unicode is built;

    submethod TWEAK {
        $!raw = $!face.raw;
        if self.cid-to-gid-map -> $cid-gid {
            my $gid-uni:= $!face.index-to-unicode;
            for $cid-gid.kv -> $cid, $gid {
                if $gid {
                    my $cp := $gid-uni[$gid];
                    if $cp {
                        @!to-unicode[$cid] = $cp
                    }
                    else {
                        @!used-cid[$cid] = 1;
                    }
                }
            }
        }
        else {
            @!to-unicode = $!face.index-to-unicode;
        }
    }

    method is-wide {True}

    method set-encoding($ord, $cid) {
        @!to-unicode[$cid] ||= $ord;
        %!charset{$ord} ||= $cid;        
        $cid;
    }

    method add-encoding(UInt:D $ord) {
        my $gid = $!raw.FT_Get_Char_Index($ord);
        my $cid;
        if self.cid-to-gid-map -> $map {
            if $ord <= $!raw.num-glyphs && !@!to-unicode[$ord] && !@!used-cid[$ord] {
                $cid = $ord;
            }
            else {
                $cid = self.allocate-cid;
            }
            $map[$cid] = $gid
                if $cid;
        }
        else {
            $cid = $gid;
        }
        self.set-encoding: $ord, $cid
    }

    multi method encode(Str $text, :cids($)!) {
        $.lock.protect: {
            blob16.new: $text.ords.map: -> $ord {
                self.add-encoding($ord);
            }
        }
    }

    has UInt $!next-cid = 0;
    has uint8 @!used-cid;
    method allocate-cid {
        repeat {
            $!next-cid++;
        } while @!used-cid[$!next-cid] || @!to-unicode[$!next-cid] && $!next-cid <= $!raw.num-glyphs;
        my $cid = $!next-cid <= $!raw.num-glyphs ?? $!next-cid !! 0;
        @!used-cid[$cid] = 1;
        $cid;
    }

    method encode-cids(@cids is raw) {
        my blob8 $buf := pack(@cids, 16);
        $buf.decode: 'latin-1';
    }

    multi method encode(Str $text --> Str) {
        self.encode-cids: self.encode($text, :cids);
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
