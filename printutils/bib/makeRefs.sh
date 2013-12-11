mysql -D stedt -e "select * from srcbib" > srcbib.csv
mysql -D stedt -e "select srcabbr from srcbib" > cites.csv
perl makeBib.pl srcbib.csv > stedtreferences.bib
xelatex stedt_test1.tex 
bibtex stedt_test1.aux
xelatex stedt_test1.tex 
xelatex stedt_test1.tex 
