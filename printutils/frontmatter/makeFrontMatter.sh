cp masterTemplate.tex frontmatter$1.tex
if [ "$1" = '1col' ] ; then
perl -i -pe 's/\\documentclass\[11pt,/\% \\documentclass[11pt,/'  frontmatter$1.tex
perl -i -pe 's/\% \\documentclass\[11pt\]/\\documentclass[11pt]/'  frontmatter$1.tex
fi
cp *.tex ../disExperiment1/tex
cd ../disExperiment1/tex
xelatex frontmatter$1.tex
bibtex frontmatter$1.aux
xelatex frontmatter$1.tex
xelatex frontmatter$1.tex
