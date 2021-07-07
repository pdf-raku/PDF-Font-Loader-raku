unit class PDF::Font::Loader::Glyph
    is repr('CStruct')
    is export(:Metrics);

use Font::FreeType::Raw::Defs;

has str $.name;
has uint32 $.code-point;  # unicode mapping (if known)
has FT_UInt $.cid;    # encoding point
has FT_UInt $.gid;    # font glyph index
has FT_UInt $.dx is rw;     # unscaled x displacement x 1000
has FT_UInt $.dy is rw = 0; # unscaled y displacement x 1000 (not yet used)

