./makeFascOnly.sh 1 x x
./makeFascOnly.sh 2 x x
./makeFascOnly.sh 3 x x
./makeFascOnly.sh 4 x x
./makeFascOnly.sh 5 x x
./makeFascOnly.sh 6 x x
./makeFascOnly.sh 7 x x
./makeFascOnly.sh 8 x x
./makeFascOnly.sh 9 x x
./makeFascOnly.sh 10 x x
cd tex
grep "include{" *master* | perl -pe s'/.*://' > includes.tex
#xelatex masterMaster.tex > master.log &
#cp masterMaster.pdf /home/stedt/public_html/dissemination
