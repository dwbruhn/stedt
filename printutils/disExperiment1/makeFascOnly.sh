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
# exit on errors..
set -e
perl extract.pl $1 $2 $3 $4
cd tex/
cp ../../frontmatter/*.tex .
#texfile=`ls $1-$2-$3-master` 
texfile="$1-$2-$3-master" 
# TeX it!     
xelatex ${texfile}.tex # > /dev/null
bibtex ${texfile}.aux
perl -i -pe 's/1989\{/1989/'  ${texfile}.bbl
xelatex ${texfile}.tex # > /dev/null
xelatex ${texfile}.tex # > /dev/null
xelatex ${texfile}.tex # > /dev/null
