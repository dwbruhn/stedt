rm *.aux *.bbl *.blg *.log *.out *.pdf stedtreferences.bib 

# use local db_creds file for db login info
mysql --defaults-extra-file=db_creds --default-character-set=utf8 -D stedt -e "select * from srcbib" > srcbib.csv


# a few ad hoc changes...fix database, then remove the following hack
perl -i -pe 's/\\n//g;' srcbib.csv
perl -i -pe 's/\\\\textup/\\textup/' srcbib.csv
perl -i -pe 's/\\\\textit\{/\{\\it /' srcbib.csv
perl -i -pe 's/\&/\\&/g;' srcbib.csv

#more ad hoc changes for problematic sources --- would be ideal to have makeRefs.pl wrap all characters of the type /(\p{Han}+)/u
perl -i -pe 's/Lǐ Fànwén 李范文/Lǐ Fànwén \\SC{李范文}/' srcbib.csv
perl -i -pe 's/《夏漢字典》/\\TC{《夏漢字典》}/' srcbib.csv
perl -i -pe 's/上古漢語的N- 和 m- 前綴/\\TC{上古漢語的}N- \\TC{和} m- \\TC{前綴}/' srcbib.csv
perl -i -pe 's/汉语历史音韵学/\\SC{汉语历史音韵学}/' srcbib.csv
perl -i -pe 's/中国社会科学出版社/\\SC{中国社会科学出版社}/' srcbib.csv

perl -i -pe 's/卒/\\SC{卒}/' srcbib.csv
perl -i -pe 's/Tibetan sdud/Tibetan \\textit{sdud}/' srcbib.csv
perl -i -pe 's/\*st- hypothesis/\\textbf{\*st-} hypothesis/' srcbib.csv
perl -i -pe 's/KL-/\\textbf{KL-}/' srcbib.csv
cut -f1  srcbib.csv > cites.csv
#mysql -D stedt -u root -e "select srcabbr from srcbib" > cites.csv

python bibseminate.py
perl makeBib.pl srcbib.csv > stedtreferences.bib
python tweakimprint_beta.py
perl -i -pe 's/address\t\=\ \{Edited by Paul Sidwell\, Doug Cooper\, and Christian Bauer\.\ Canberra\}\,/
address\t\=\ \{Canberra. Edited by Paul Sidwell\, Doug Cooper\, and Christian Bauer\}\,/' stedtreferences.bib

xelatex bibtest.tex 
bibtex bibtest.aux
#perl -i -pe 's/1989\}\{/1989\}/' bibtest.bbl
perl -i -pe 's/1989\{/1989/' bibtest.bbl
# replace -- with en-dashes in year and page ranges
perl -i -pe 's/--/\xe2\x80\x93/g' bibtest.bbl
xelatex bibtest.tex
xelatex bibtest.tex
cp stedtreferences.bib ..
cp stedtreferences.bib ../disExperiment1/tex
cp stedtreferences.bib ../frontmatter
