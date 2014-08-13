#!/bin/bash -x
source ~/.bashrc
date
set verbose
DATE=`date "+%Y-%m-%d"`
cd ~/printutils
svn up
#
rm ~/printutils/disExperiment1/tex/*
cd ~/printutils/bib
./makeRefs.sh > ~/printutils/shebang.log 2>&1
cd ~/printutils/disExperiment1
time ./shebang.sh >> ~/printutils/shebang.log 2>&1
cp ~/printutils/disExperiment1/tex/masterTemp.pdf ~stedt/public_html/dissemination/master$DATE.pdf
# copy log
cp ~/printutils/shebang.log ~stedt/public_html/dissemination/shebang$DATE.log
date
