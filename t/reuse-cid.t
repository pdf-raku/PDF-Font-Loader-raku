use v6;
use Test;
use PDF::Lite;
use PDF::Font::Loader;
use PDF::Content::FontObj;

plan 10;
# see if we can re-load the CID font that we wrote in pdf-text.align.t

class FontLoader {
    # load fonts from a rendering class
    # this seems like the most likely way this loader will be used
    # in practice; load fonts from a PDF as they are referenced
    use PDF::Content::Ops :OpCode;
    has Bool %!seen{Any};

    # intercept just the SetFont Graphics operation
    method callback{
        sub ($op, *@args) {
            my $method = OpCode($op).key;
            self."$method"(|@args)
                if $method ~~ 'SetFont';
        }
    }
    method render($content) {
        $content.render(:$.callback);
    }
    method SetFont(Str $font-key, Numeric $font-size) {
        with $*gfx.resource-entry('Font', $font-key) -> $dict {
            take PDF::Font::Loader.load-font: :$dict, :embed
               unless %!seen{$dict}++;
        }
    }
}

sub font-sanity($font) {
    # a few sanity checks
    isa-ok $font, 'PDF::Font::Loader::FontObj', 'loaded a FreeType font';
    like $font.font-name, /^[<[A..Z]>**6'+']?'BitstreamVeraSans-Roman'$/, 'font name';
    ok( 1100 < $font.height < 1900, 'font height')
        or diag "unexpected font height: {$font.height}";
    # first few characters in the subset
    is-deeply $font.encode('A', :str), "\0\x[24]";
    is-deeply $font.decode("\0\x[24]", :str), 'A';
    is-deeply $font.encode('€', :str), "\x[1]\x[2]";
    is-deeply $font.decode("\x[1]\x[2]", :str), '€';
    my $text = "Abc€√b";
    my $enc = $font.encode($text, :str);
    is-deeply $enc, [~]("\0\x[24]", "\0\x[45]", "\0\x[46]", "\x[1]\x[2]", "\x[0]\x[a5]", "\0\x[45]"), 'encode';
    is $font.decode($enc, :str), $text, "font encode/decode round-trip";
    nok $font.file, 'lacks an external file path';
}

my PDF::Lite $pdf .= open: "t/pdf-text-align.pdf";
my PDF::Content::FontObj $f;
for gather FontLoader.new.render: $pdf.page(1) -> PDF::Content::FontObj $font {
    font-sanity($font);
    $f = $font;
}
$pdf.add-page.graphics: {
    .font = $f;
    .say: "reused Vera (CID) font", :position[10,500];
}

my $basename := "t/reuse-cid";
$pdf.id =  "{$basename}.t".fmt('%-16s').substr(0,16);
$pdf.save-as: "{$basename}.pdf";

done-testing;
