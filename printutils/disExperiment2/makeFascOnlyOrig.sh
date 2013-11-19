#
# script to generate a "fascicle chunk" and make it public"
# needs to be run as user stedt-cgi-ssl 
#
# syntax:
#
# ./makeFasc.sh 1 7 2 [--i]
#
# if --i is specified, the draft format is created and moved to the site, 
# but the ToC is not updated.
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
cd ~stedt-cgi-ssl/rootcanals/
cd tex/
rm $1-$2-$3-*
cd ..
# exit on errors..
set -e
# generate the .tex file
perl extract.pl $1 $2 $3 $4
cd tex/
texfile=`ls $1-$2-$3-master.tex` 
# TeX it!     
xelatex $texfile # > /dev/null
xelatex $texfile # > /dev/null
xelatex $texfile # > /dev/null
