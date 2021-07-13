use PDF::Font::Loader::FontObj :FontFlags;

#| Implements a PDF CID font
unit class PDF::Font::Loader::FontObj::CID
    is PDF::Font::Loader::FontObj;

use PDF::COS::Name;
use PDF::IO::Util :pack;
use PDF::IO::Writer;
use PDF::COS::Stream;

sub prefix:</>($name) { PDF::COS::Name.COERCE($name) };

submethod TWEAK {
    if self.encoding.starts-with('Identity') {
        die "can't use {self.encoding} encoding with unembedded font {self.font-name}"
            unless self.is-embedded;
    }
}

# /Subtype entry for the descendant CID font
method !cid-font-type-entry {
    given $.face.font-format {
        when 'CFF' { 'CIDFontType0' }
        when 'TrueType'|'OpenType'    {'CIDFontType2'}
        default { fail "unable to handle CID font type: $_" }
    }
}

method !make-widths {
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

method !make-gid-map {
    my $cids = $.encoder.cid-to-gid-map;
    my $decoded = unpack($cids, 16);
    PDF::COS::Stream.COERCE: { :$decoded };
}

method finish-font($dict, :$save-widths, :$save-gids) {
    $dict<ToUnicode> //= self.make-cmap-stream
        if self.has-encoding;

    $dict<DescendantFonts>[0]<W> = self!make-widths
        if $save-widths;
            
    $dict<CIDToGIDMap> = self!make-gid-map
        if $save-gids && !self.enc.starts-with('identity');    
}

method make-dict {
    my $BaseFont = /($.font-name);
    my $Type = /<Font>;
    my $Encoding = /(self.encoding);
    my $dict = PDF::COS::Dict.COERCE: %(
        :Type( /<Font> ),
        :Subtype( /<Type0> ),
        :$BaseFont,
        :$Encoding,
    );


    my $cid-font = {
        :$Type,
        :Subtype(/(self!cid-font-type-entry)),
        :$BaseFont,
        :CIDToGIDMap( /<Identity> ),
        :$.CIDSystemInfo
    };

    with self.font-descriptor {
        .<Flags> +|= FontFlags::Symbolic;
        $cid-font<FontDescriptor> = $_;
    }

    $dict<DescendantFonts> = [ $cid-font ];
    $dict<DescendantFonts>[0].is-indirect = True;
    $dict;
}

=begin pod

=head2 Description

This is a subclass of L<PDF::Font::Loader::FontObj> for representing PDF CID fonts, introduced with PDF v1.3.

The main defining characteristic of CID font is their abililty to support multi-byte (usually 2-byte) encodings.

Loading a font with a multi-byte (or potentially multi-byte) encoding such as `identity-h` or `cmap` with get created with a L<PDF::Font::Loader::FontObj::CID> object.

=end pod
