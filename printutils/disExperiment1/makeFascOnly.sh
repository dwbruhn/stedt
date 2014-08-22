#
# script to generate a "fascicle chunk"
#
# syntax:
#
# ./makeFasc.sh 1 7 2
#
if [ -z $1 ] ; then echo need a value for V; exit ; fi
if [ -z $2 ] ; then echo need a value for F; exit ; fi
if [ -z $3 ] ; then echo need a value for C; exit ; fi
# first, get to the right place
if [ "$4" = '--i' ] ; then
DRAFT="-draft"
else
DRAFT=""
fi
# verbose...
set -x
rm tex/$1-$2-$3-*
lockfile -20 -l 600 -r20 master.lock
cp ../frontmatter/masterTemplate.tex tt/master.tt
perl -i -pe 's/^.include.introduction.*$//' tt/master.tt
perl -i -pe 's/^.include.acknowledgements.*$//' tt/master.tt
perl -i -pe 's/^.include.terminology.*$//' tt/master.tt
perl -i -pe 's/^.include.preface.*$//' tt/master.tt
perl -i -pe 's/^.include.epigraph.*$//' tt/master.tt
perl -i -pe 's/^.title.*$//' tt/master.tt
perl -i -pe 's/^.author.*$//' tt/master.tt
perl -i -pe 's/^\%\%\%\%.//' tt/master.tt
# exit on errors..
set -e
perl extract.pl $1 $2 $3 $4
rm -f master.lock
cd tex/
cp ../../frontmatter/*.tex .
#texfile=`ls $1-$2-$3-master` 
texfile="$1-$2-$3-master" 
# TeX it!     
if [ "$4" = '--x' ] ; then
  exit
fi
xelatex ${texfile}.tex > ${texfile}.stdout.log
bibtex ${texfile}.aux  >> ${texfile}.stdout.log
# this is a workaround for bibtex: it goofs when more than 26 cites appear for an author/year.
perl -i -pe 's/1989\{/1989/'  ${texfile}.bbl
xelatex ${texfile}.tex >> ${texfile}.stdout.log
xelatex ${texfile}.tex >> ${texfile}.stdout.log
makeindex ${texfile} >> ${texfile}.stdout.log
xelatex ${texfile}.tex >> ${texfile}.stdout.log
xelatex ${texfile}.tex >> ${texfile}.stdout.log
