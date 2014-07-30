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
cd ~/printutils/frontmatter
./makeFrontMatter.sh 1col
cp ~/printutils/disExperiment1/tex/frontmatter1col.pdf ~stedt/public_html/dissemination/frontmatter1col$DATE.pdf
#
rm ~/printutils/disExperiment1/tex/*
cd ~/printutils/bib
./makeRefs.sh > ~/printutils/shebang.log 2>&1
cd ~/printutils/disExperiment1
time ./shebang.sh >> ~/printutils/shebang.log 2>&1
cp ~/printutils/disExperiment1/tex/masterTemp.pdf ~stedt/public_html/dissemination/master$DATE.pdf
# extract comparanda and footnotes
cd ~/printutils/disExperiment1/footnotes
time ./comp_extractor.sh >> ~/printutils/shebang.log 2>&1
time ./fn_extractor.sh >> ~/printutils/shebang.log 2>&1
cp ~/printutils/disExperiment1/footnotes/comp_wrapper.pdf ~stedt/public_html/dissemination/comparanda$DATE.pdf
cp ~/printutils/disExperiment1/footnotes/fn_wrapper.pdf ~stedt/public_html/dissemination/footnotes$DATE.pdf
# extract prettified protoforms
cd ~/printutils/disExperiment1/protoforms
time ./pforms_extractor.sh >> ~/printutils/shebang.log 2>&1
cp ~/printutils/disExperiment1/protoforms/pforms_wrapper.pdf ~stedt/public_html/dissemination/protoforms$DATE.pdf
# copy log
cp ~/printutils/shebang.log ~stedt/public_html/dissemination/shebang$DATE.log
date
