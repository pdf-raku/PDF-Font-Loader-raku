unit class PDF::Font::Loader::Metrics
    is repr('CStruct')
    is export(:Metrics);

use Font::FreeType::Raw::Defs;

has uint32 $.code-point;
has FT_UInt $.cid;
has num64 $.dx;
has num64 $.dy = 0e0; # Not yet used

