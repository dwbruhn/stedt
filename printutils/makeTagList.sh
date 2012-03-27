#
# script to generate a "tagging document"
#
# syntax:
#
# ./makeTagList.sh "gloss1,gloss2,gloss3"
#
# first, get to the right place
cd ~stedt-cgi-ssl/rootcanals/
# generate the .tex file
perl residue.pl $1
#texfile=`ls $1.tex`
texfile="untagged.tex"
# TeX it!     
cd tex
xelatex $texfile
xelatex $texfile
xelatex $texfile
pdffile=`ls untagged.pdf`
DATETIME=`date '+%Y%m%d'`
#DATETIME=`date '+%Y%m%d_%H%M%S'`
# move the new pdf to the dissemination directory
cp $pdffile ~stedt/public_html/taglists/$DATETIME.pdf
#perl ~stedt/public_html/makeToC.pl > ~stedt/public_html/dissemination.html       
echo "done with $1"
