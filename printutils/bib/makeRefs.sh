rm *.aux *.bbl *.blg *.log *.out *.pdf stedtreferences.bib 

# use local db_creds file for db login info
mysql --defaults-extra-file=db_creds --default-character-set=utf8 -D stedt -e "select * from srcbib" > srcbib.csv


# a few ad hoc changes...fix database, then remove the following hack
perl -i -pe 's/DQ-Yi \(Axi\)/DQ-Yi-Axi/' srcbib.csv
perl -i -pe 's/Evans, Jonathan P., John B. Lowe, Jackson T. S. Sun/Evans, Jonathan P. and Lowe, John B. and Sun, Jackson T. S./' srcbib.csv
perl -i -pe 's/Chen Shilin, Bian Shiming, Li Xiuqing, eds./{Chen Shilin} and {Bian Shimin} and {Li Xiuqing}, eds./' srcbib.csv
perl -i -pe 's/Hari, Maria, Doreen Taylor, and Kenneth L. Pike,*/Hari, Maria and Taylor, Doreen and Pike,Kenneth L./' srcbib.csv
perl -i -pe 's/SY-Kh.*zhaQ/SY-KhozhaQ/g' srcbib.csv
perl -i -pe 's/\\n//g;' srcbib.csv
perl -i -pe 's/Dai Qingxia, Liu Juhuang, and Fu Ailan/Dai Qingxia and Liu Juhuang, and Fu Ailan/g;' srcbib.csv
perl -i -pe 's/Noonan, M., W. Pagliuca, and R. Bhulanja/Noonan, M. and Pagliuca, W. and R. Bhulanja/g;' srcbib.csv
perl -i -pe 's/Rai, Krishna Prasad, Anna Holzhausen, and Andreas Holzhausen/Rai, Krishna Prasad and Holzhausen, Anna and Holzhausen, Andreas/g;' srcbib.csv
perl -i -pe 's/Taylor, Doreen, Fay Everitt, and Karna Bahadur Tamang/Taylor, Doreen and Everitt, Fay and Tamang, Karna Bahadur/g;' srcbib.csv
perl -i -pe 's/Rai, Novel Kishore, Tikka Ram Rai, and Werner Winter/Rai, Novel Kishore and Rai,Tikka Ram and Winter, Werner/g;' srcbib.csv
perl -i -pe 's/Thurgood, Graham, James A. Matisoff, and David Bradley, eds./Thurgood, Graham and Matisoff, James A.  and Bradley, David , eds./g;' srcbib.csv
perl -i -pe 's/MA Linying, Dennis Walters, and Susan Walters/Linying MA and Walters ,Dennis and Walters, Susan/g;' srcbib.csv
perl -i -pe 's/Brassett, Philip \& Cecilia, and LU Meiyan/Brassett, Philip \& Cecilia and Lu Meiyan/g;' srcbib.csv
perl -i -pe 's/Balawan, M., S.D.B., M.Sc./Balawan, M./g;' srcbib.csv
perl -i -pe 's/Bandhu, Chuda Mani, B. N. Dahal, A. Holzhausen and A. Hale/Bandhu, Chuda Mani and Dahal, B. N. and Holzhausen, A. and A. Hale/g;' srcbib.csv
perl -i -pe 's/Chen Shilin, Li Min, et al., eds./Chen Shilin and Li Min, et al., eds./g;' srcbib.csv
perl -i -pe 's/Dai Qingxia, Xu Xigen, Shao Jiacheng, Qiu Xiangkun/Dai Qingxia and Xu Xigen and Shao Jiacheng and Qiu Xiangkun/g;' srcbib.csv
perl -i -pe 's/Xu Lin, Mu Yuzhang, Gai Xingzhi, eds./Xu Lin and Mu Yuzhang and Gai Xingzhi, eds./g;' srcbib.csv
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
perl -i -pe 's/--/\xe2\x80\x93/' bibtest.bbl
xelatex bibtest.tex
xelatex bibtest.tex
cp stedtreferences.bib ..
cp stedtreferences.bib ../disExperiment1/tex
cp stedtreferences.bib ../frontmatter
