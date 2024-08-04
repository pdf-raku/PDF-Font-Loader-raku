#| Implements a PDF CID font
unit class PDF::Font::Loader::FontObj::CID;

use PDF::Font::Loader::FontObj :FontFlags;
also is PDF::Font::Loader::FontObj;

use PDF::COS::Name;
use PDF::IO::Util :pack;
use PDF::IO::Writer;
use PDF::COS::Stream;
use PDF::Font::Loader::Enc::CMap;
use PDF::Font::Loader::Enc::Identity16;
use PDF::Font::Loader::Enc::Unicode;

sub prefix:</>($name) { with $name {PDF::COS::Name.COERCE($_)} else { Any } };

submethod TWEAK {
    if self.enc ~~ m/^[identity|utf]/ {
        die "can't use {self.enc} encoding with unembedded font {self.font-name}"
            unless self.embed || self.is-embedded;
    }
}

# /Subtype entry for the descendant CID font
method !cid-font-type-entry {
    given $.face.font-format {
        when 'CFF'|'OpenType' { 'CIDFontType0' }
        when 'TrueType'       {'CIDFontType2'}
        default { fail "unable to handle CID font type: $_" }
    }
}

method !make-widths {
    my $tail;
    my @W;
    my uint $j = -2;
    my @widths := @.widths;
    my uint16 $fc = $.first-char;
    my uint16 $n = $.last-char - $fc;
    loop (my uint16 $i = 0; $i <= $n; $i++) {
        if @widths[$i] -> $width is copy {
            $width = 0 if $width < 0;
            if ++$j == $i {
                $tail.push: $width;
            }
            else {
                $tail = [$width, ];
                $j = $i;
                my uint16 $cid = $i + $fc;
                @W.append: ($cid, $tail);
            }
        }
    }
    @W;
}

method !make-gid-map {
    my $cids = $.encoder.cid-to-gid-map;
    my $decoded = unpack($cids, 16);
    PDF::COS::Stream.COERCE: { :$decoded };
}

method !make-encoding-stream {
    $.encoder.cid-cmap //= do {
        my $name = [~] (
            $.font-name, '-Custom',
            ($.encoder.isa(PDF::Font::Loader::Enc::Unicode)
             ?? '-' ~ $.encoder.enc.uc
             !! ''),
            '-H'
        );
        
        my PDF::COS::Name() $CMapName = $name;
        my PDF::COS::Name() $Type = 'CMap';

        PDF::COS::Stream.COERCE: %( :dict{
            :$Type,
            :$CMapName,
            :$.CIDSystemInfo,
        });
    }

    given $.encoder.cid-cmap {
        when PDF::COS::Stream {
            .decoded = $.encoder.make-encoding-cmap;
        }
    }
    $.encoder.cid-cmap;
}

method finish-font($dict, :$save-widths, :$save-gids) {
    if self.has-encoding {
        $dict<ToUnicode> //= self.make-to-unicode-stream;
    }
    if $.encoder.isa(PDF::Font::Loader::Enc::CMap) && $.encoder.code2cid {
        $dict<Encoding> //= self!make-encoding-stream;
    }

    $dict<DescendantFonts>[0]<W> = self!make-widths
        if $save-widths;
            
    $dict<CIDToGIDMap> = self!make-gid-map
        if $save-gids && ! $.encoder.isa(PDF::Font::Loader::Enc::Identity16)
}

method font-descriptor {
    given callsame() {
        .<Flags> +|= FontFlags::Symbolic;
        $_;
    }
}

method make-dict {
    my $BaseFont = /($.font-name);
    my $Type = /<Font>;
    my $FontDescriptor = self.font-descriptor;
    my PDF::COS::Dict() $cid-font = {
        :$Type,
        :Subtype(/(self!cid-font-type-entry)),
        :$BaseFont,
        :$FontDescriptor,
        :CIDToGIDMap( /<Identity> ),
        :$.CIDSystemInfo
    };
    $cid-font.is-indirect = True;

    my PDF::COS::Dict() $dict = %(
        :$Type,
        :Subtype( /<Type0> ),
        :$BaseFont,
        :DescendantFonts[ $cid-font ],
    );
    given self.encoding {
        $dict<Encoding> = /($_)
            unless $_ ~~ 'CMap'|'StandardEncoding'; # implied anyway;
    }
    $dict;
}

=begin pod

=head2 Description

This is a subclass of L<PDF::Font::Loader::FontObj> for representing PDF CID fonts, introduced with PDF v1.3.

The main defining characteristic of CID (Type0) fonts is their abililty to support multi-byte (usually 2-byte) encodings.

This class is used for all fonts with a multi-byte (or potentially multi-byte) encoding such as `identity-h` or `cmap`.

=head3 Methods

This class inherits from L<PDF::Font::Loader::FontObj> and has all its methods available.

It provides CID specific implementations of the `finish-font`,
`font-descriptor` and `make-dict` methods, but introduces no new methods.

=end pod
