all : doc

doc : README.md

README.md : lib/PDF/Font/Loader.pm
	(\
	    echo '[![Build Status](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6.svg?branch=master)](https://travis-ci.org/p6-pdf/PDF-Font-Loader-p6)'; \
            echo '';\
            perl6 -I . --doc=Markdown lib/PDF/Font/Loader.pm\
        ) > README.md

test :
	@prove -e"perl6 -I ." t

loudtest :
	@prove -e"perl6 -I ." -v t

