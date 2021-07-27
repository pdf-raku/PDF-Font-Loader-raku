use PDF::Font::Loader::Enc::CMap :CodeSpace;

#| CMap based encoding/decoding
unit class PDF::Font::Loader::Enc::Unicode
    is PDF::Font::Loader::Enc::CMap;

has Str:D $.enc is required where 'utf8'|'utf16'|'utf32';
has uint64 $!width;

submethod TWEAK {
    $!width = 1 +< %( :utf8(8), :utf16(16), :utf32(32) ){$!enc};
    self.codespaces = (do given $!enc {
        when 'utf8' {
            ([0x00],                   [0x7F]),
            ([0xC0, 0x80],             [0xDF, 0xBF]),
            ([0xE0, 0x80, 0x80],       [0xEF, 0xBF, 0xBF]),
            ([0xF0, 0x80, 0x80, 0x80], [0xF7, 0xBF, 0xBF, 0xBF] ),
        }
        when 'utf16' {
            ([0x00, 0x00], [0xD7, 0xFF]), # BMP1
            ([0xD8, 0x00, 0xDC, 0x00], [0xDB, 0xFF, 0xDF, 0xFF]), # Surrogates
            ([0xE0, 0x00], [0xFF, 0xFF]), # BMP2
        }
        when 'utf32' {
            (([0x00, 0x00, 0x00, 0x00], [0x00, 0x10, 0xFF, 0xFF]),)
        }
    }).map: {
        my @from = .[0];
        my @to = .[1];
        CodeSpace.new(:@from, :@to);
    }
}

method is-wide { True }

method allocate(Int $ord) {
    my uint $cid = $.face.raw.FT_Get_Char_Index($ord);
    my uint32 $code = 0;

    self.set-encoding($ord, $cid);

    if $ord < 128 || self.enc eq 'utf32' {
        $code = $ord;
    }
    else {
        my utf8 $buf := $ord.chr.encode($!enc);
        for $buf.list {
            $code *= $!width;
            $code += $_;
        }
    }

    self.code2cid{$code} = $cid;
    self.cid2code{$cid}  = $code;

    $cid;
}
