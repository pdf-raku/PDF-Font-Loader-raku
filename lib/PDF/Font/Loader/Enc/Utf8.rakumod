use PDF::Font::Loader::Enc::CMap :CodeSpace;

#| CMap based encoding/decoding
unit class PDF::Font::Loader::Enc::Utf8
    is PDF::Font::Loader::Enc::CMap;

submethod TWEAK {
    self.codespaces = (
        ( [0x00],                   [0x7F]),
        ( [0xC0, 0x80],             [0xDF, 0xBF]),
        ( [0xE0, 0x80, 0x80],       [0xEF, 0xBF, 0xBF]),
        ( [0xF0, 0x80, 0x80, 0x80], [0xF7, 0xBF, 0xBF, 0xBF] ),
    ).map: {
        my @from = .[0];
        my @to = .[1];
        CodeSpace.new(:@from, :@to);
    }
}

method is-wide { True }

method allocate(Int $ord) {
    my uint $cid = $.face.raw.FT_Get_Char_Index($ord);
    my uint64 $code = 0;

    self.set-encoding($ord, $cid);

    if $ord < 128 {
        $code = $ord;
    }
    else {
        my utf8 $buf := $ord.chr.encode;
        for $buf.list {
            $code *= 256;
            $code += $_;
        }
    }

    self.code2cid{$code} = $cid;
    self.cid2code{$cid}  = $code;

    $cid;
}
