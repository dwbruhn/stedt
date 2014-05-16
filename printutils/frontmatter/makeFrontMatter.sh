cp masterTemplate.tex frontmatter$1.tex
if [ "$1" = '1col' ] ; then
perl -i -pe 's/\\documentclass\[11pt,/\% \\documentclass[11pt,/'  frontmatter$1.tex
perl -i -pe 's/\% \\documentclass\[11pt\]/\\documentclass[11pt]/'  frontmatter$1.tex
perl -i -pe 's/\\twocolumn//'  frontmatter$1.tex
#
perl -i -pe 's/^(.geometry)/% \1/' frontmatter$1.tex
perl -i -pe 's/paperwidth.17in./paperwidth{8.5in}/' frontmatter$1.tex
perl -i -pe 's/paperheight.26in./paperheight{11in}/' frontmatter$1.tex
perl -i -pe 's/textwidth.15in./textwidth{7.4in}/' frontmatter$1.tex
perl -i -pe 's/textheight.23.5in./textheight{8.6in}/' frontmatter$1.tex
perl -i -pe 's/columnwidth.7.2in./columnwidth{7.0in}/' frontmatter$1.tex
#
fi
cp *.tex ../disExperiment1/tex
cd ../disExperiment1/tex
rm *.toc *.aux *.bbl *.blg *.log *.out
xelatex frontmatter$1.tex
bibtex frontmatter$1.aux
xelatex frontmatter$1.tex
xelatex frontmatter$1.tex
xelatex frontmatter$1.tex
