#
# script to generate a "fascicle chunk" and make it public"
# needs to be run as user stedt-cgi-ssl 
#
# syntax:
#
# ./makeFasc.sh 1 7 2
#
# first, get to the right place
cd ~stedt-cgi-ssl/rootcanals/
# generate the .tex file
perl extract.pl $1 $2 $3
cd tex/
rm "$1-$2-$3.*"
texfile=`ls $1-$2-$3*.tex` 
# TeX it!     
xelatex $texfile
xelatex $texfile
xelatex $texfile
pdffile=`ls $1-$2-$3*.pdf`
pdffile=${pdffile%.*}
DATETIME=`date '+%Y%m%d'`
#DATETIME=`date '+%Y%m%d_%H%M%S'`
# move the new pdf to the dissemination directory
cp $pdffile.pdf ~stedt/public_html/dissemination/$pdffile-$DATETIME-1.pdf
# update the ToC for the electronic etymologies
perl ~stedt/public_html/makeToC.pl > ~stedt/public_html/dissemination.html       
echo "done with $texfile" 