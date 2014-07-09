cp masterTemplate.tex lglistCheck.tex
perl lglist.pl > lglist.tex
rm ../disExperiment1/tex/lglistCheck.*
cp *.tex ../disExperiment1/tex
cd ../disExperiment1/tex
xelatex lglistCheck.tex
bibtex  lglistCheck.aux
xelatex lglistCheck.tex
xelatex lglistCheck.tex
xelatex lglistCheck.tex
