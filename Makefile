all : doc

doc : README.md

README.md : lib/PDF/Font/Loader.rakumod
	(\
	    echo '[![Build Status](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6.svg?branch=master)](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6)'; \
            echo '';\
            perl6 -I . --doc=Markdown lib/PDF/Font/Loader.rakumod\
        ) > README.md

test :
	@prove -e"raku -I ." t

loudtest :
	@prove -e"raku -I ." -v t

