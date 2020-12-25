DocProj=pdf-raku.github.io
DocRepo=https://github.com/pdf-raku/$(DocProj)
DocLinker=../$(DocProj)/etc/resolve-links.raku

all : doc

doc : $(DocLinker) README.md

README.md : lib/PDF/Font/Loader.rakumod
	(\
	    echo '[![Build Status](https://travis-ci.org/pdf-raku/PDF-Font-Loader-raku.svg?branch=master)](https://travis-ci.org/pdf-raku/PDF-Font-Loader-raku)'; \
            echo '';\
            raku -I . --doc=Markdown lib/PDF/Font/Loader.rakumod\
            | TRAIL=PDF/Font/Loader raku -p -n $(DocLinker)\
        ) > $@

test :
	@prove -e"raku -I ." t

loudtest :
	@prove -e"raku -I ." -v t

$(DocLinker) :
	(cd .. && git clone $(DocRepo) $(DocProj))
