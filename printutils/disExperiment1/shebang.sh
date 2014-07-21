##
#
# this script makes the entire STEDT.
# it takes a while to run (15-20 mins, depending)
#
# first, make all the volumes..
./makeFascOnly.sh 2 x x $1 & 
./makeFascOnly.sh 3 x x $1 & 
./makeFascOnly.sh 4 x x $1 & 
./makeFascOnly.sh 5 x x $1 & 
./makeFascOnly.sh 6 x x $1 & 
./makeFascOnly.sh 7 x x $1 & 
./makeFascOnly.sh 8 x x $1 & 
./makeFascOnly.sh 9 x x $1 & 
./makeFascOnly.sh 10 x x $1 & 
./makeFascOnly.sh 1 x x $1 & 
wait # for them all to complete...
# update language list
perl ../frontmatter/lglist.pl > ../frontmatter/lglist.tex
cd tex
if [ "$1" = '--x' ] ; then
  exit
fi
# this cp is not strictly necessary since makeFascOnly.sh does it...but, just in case
# something changes.
cp ../../frontmatter/*.tex .
# insert the various little tex files into the master template
> inputs.tex
for i in {1..10}
do
   title=`grep "pdfbookmark" ${i}-x-x-master.tex | grep -v TOC | perl -pe 's/.pdfbookmark\[1\].*?{([\d\. ]+)(.*?)\}.*/\2/'`
   echo "\begin{part}{$title}" >> inputs.tex
   perl -ne "print if/input\{\d+\-/" ${i}-x-x-master.tex | perl -pe s'/.*://' >> inputs.tex
   echo "\end{part}" >> inputs.tex
done
sed -e '/% insert includes here/r./inputs.tex' masterTemplate.tex > masterTemp.tex 
xelatex masterTemp.tex > master.log
bibtex masterTemp  > master.bibtex.log
xelatex masterTemp.tex >> master.log
xelatex masterTemp.tex >> master.log
makeindex masterTemp > master.makeindex.log
xelatex masterTemp.tex >> master.log
xelatex masterTemp.tex >> master.log
