rm *.aux *.bbl *.blg *.log *.out
cd ..
perl lglist.pl > ./lglist/lglist.tex
cp lglist.tex ./lglist
cp stedtreferences.bib ./lglist
cd lglist
xelatex lglist_wrapper.tex
bibtex lglist_wrapper.aux
xelatex lglist_wrapper.tex
xelatex lglist_wrapper.tex