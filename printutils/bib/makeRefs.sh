mysql -D stedt -e "select * from srcbib" > srcbib.csv
mysql -D stedt -e "select srcabbr from srcbib" > cites.csv
perl makeBib.pl srcbib.csv > stedtreferences.bib
xelatex bibtest.tex 
bibtex bibtest.aux
xelatex bibtest.tex 
xelatex bibtest.tex
cp stedtreferences.bib ..
