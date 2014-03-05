##
#
# this script makes the entire STEDT.
# it takes a while to run (15-20 mins, depending)
#
./makeFascOnly.sh 1 x x & 
./makeFascOnly.sh 2 x x & 
./makeFascOnly.sh 3 x x & 
./makeFascOnly.sh 4 x x & 
./makeFascOnly.sh 5 x x & 
./makeFascOnly.sh 6 x x & 
./makeFascOnly.sh 7 x x & 
./makeFascOnly.sh 8 x x & 
./makeFascOnly.sh 9 x x & 
./makeFascOnly.sh 10 x x & 
wait
cd tex
> inputs.tex
for i in {1..10}
do
   title=`grep "pdfbookmark" ${i}-x-x-master.tex | grep -v TOC | perl -pe 's/.pdfbookmark\[1\].*?{(.*?)\}.*/\1/'`
   echo "\begin{part}{$title}" >> inputs.tex
   perl -ne "print if/input\{\d+\-/" ${i}-x-x-master.tex | perl -pe s'/.*://' >> inputs.tex
   echo "\end{part}" >> inputs.tex
done
sed -e '/% insert includes here/r./inputs.tex' masterMaster.tex > masterTemp.tex 
xelatex masterTemp.tex > master.log
#cp masterTemp.pdf /home/stedt/public_html/dissemination
