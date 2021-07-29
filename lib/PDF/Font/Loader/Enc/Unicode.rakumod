use PDF::Font::Loader::Enc::CMap :CodeSpace;

#| UTF-8/16/32 based encoding and decoding
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

# cheat for the codespace-driven base method
method enc-width($_ is raw) {
    when $!enc eq 'utf32' { 4 }
    when * >= 1 +< 24     { 4 }
    when * >= 1 +< 16     { 3 }
    when $!enc eq 'utf16' { 2 }
    when * >= 1 +< 8      { 2 }
    default { 1 }
}

method allocate(Int $ord) {
    my uint $cid = $.face.raw.FT_Get_Char_Index($ord);
    my uint32 $code = 0;

    self.set-encoding($ord, $cid);

    if $ord < 256 || self.enc eq 'utf32' {
        $code = $ord;
    }
    else {
        my Blob $buf := $ord.chr.encode($!enc);
        for $buf.list {
            $code *= $!width;
            $code += $_;
        }
    }

    self.code2cid{$code} = $cid;
    self.cid2code{$cid}  = $code;

    $cid;
}

=begin pod

=head2 Description

This is an experimental class which implements UTF-8, UTF-16 and UTF-32 encoding.

=head3 Methods

This class is based on L<PDF::Font::Loader::Enc::CMap> and has all its methods available.

=end pod
