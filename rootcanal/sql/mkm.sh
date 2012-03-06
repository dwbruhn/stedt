#
mysql -D stedt --default-character-set=utf8 -u $1 -p$2 -e "SELECT rn,reflex,gloss,gfn,language,grp,grpno,languagenames.srcabbr,lexicon.srcid,semkey,lexicon.lgid FROM lexicon,languagenames,languagegroups WHERE lexicon.lgid=languagenames.lgid AND languagenames.grpid=languagegroups.grpid;" > lexicon.csv
perl morphemes.pl < lexicon.csv > morphs.csv 
perl transduce2.pl < morphs.csv > morphemes.csv
mysql --default-character-set=utf8 --local stedt -u $1 -p$2 < ct.sql 
mv morphemes.csv morphemes.txt
mysqlimport --local --default-character-set=utf8 -u $1 -p$2 stedt  morphemes.txt
mysql --local stedt --default-character-set=utf8 -u $1 -p$2 < mkindex.sql
