#
mysql -D stedt -e "SELECT rn,reflex,gloss,gfn,language,grp,grpno,languagenames.srcabbr,lexicon.srcid,semkey,lexicon.lgid FROM lexicon,languagenames,languagegroups WHERE lexicon.lgid=languagenames.lgid AND languagenames.grpid=languagegroups.grpid;" > lexicon.csv
#
#mysql -D stedt -e "SELECT rn,analysis,reflex,gloss,semcat,lgid from lexicon;" > lexicon.csv &
perl morphemes.pl < lexicon.csv > morphs.csv 
perl transduce2.pl < morphs.csv > morphemes.csv
mysql --local stedt < ct.sql 
mv morphemes.csv morphemes.txt
mysqlimport --local stedt morphemes.txt
mysql --local stedt < mkindex.sql
