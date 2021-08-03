#| Represents a single glyph in a PDF
unit class PDF::Font::Loader::Glyph
    is export(:Metrics);

use Font::FreeType::Raw::Defs;

has Str $.name;
has uint32 $.code-point;  # unicode mapping (if known)
has FT_UInt $.cid;    # encoding point
has FT_UInt $.gid;    # font glyph index
has FT_UInt $.ax is rw;     # unscaled x advance x 1000
has FT_UInt $.ay is rw = 0; # unscaled y advance x 1000 (not yet used)

method dx is DEPRECATED<ax> { $.ax }

=begin pod

=head3 Description

This is an introspective class for looking up glyphs from font encodings.

=head3 Example

=begin code :lang<raku>
use PDF::Font::Loader::Glyph;

# load from character encodings
my PDF::Font::Loader::Glyph @glyphs = $font.glyphs: "Hi";
say @glyphs[0].raku; # Glyph.new(:name<H>, :code-point(72),  :cid(48), :gid(26), :ax(823), :ay(0))
say @glyphs[1].raku; # Glyph.new(:name<i>, :code-point(105), :cid(4),  :gid(21), :ax(334), :ay(0)

# load from CIDs
@glyphs = $font.glyphs: [48, 4];
=end code

=head3 Methods

=head3 code-point

The Unicode code-point for the glyph.

If the font has been loaded from a PDF dictionary. The glyph may not have a Unicode font mapping. In this case, `code-point` will be zero.

=head3 name

Glyph name.

=head3 cid

The PDF logical character identifier for the glyph

=head3 gid

Actual glyph identifier for the glyph. This is the index into the font's associated `face` object.

For `Identity-H` and `Identity-V` encoded fonts and other fonts without a `cid-to-gid-map` table, the `gid` will be the same as the `cid`.

=head3 ax

The width (horizontal displacement to the next glyph). The value should be multiplied by font-size / 1000 to compute
the actual displacement.

Note that the width of a glyph can be indirectly set or altered via the font object:

`$font.glyph-width('i') -= 100`

=head3 ay

The height (vertical displacement to the next glyph) for a vertically written glyph. This method is not-yet-implemented,
and always returns zero.

=end pod
