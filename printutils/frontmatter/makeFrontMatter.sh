cp *.tex ../disExperiment1/tex
cd ../disExperiment1/tex
xelatex frontmatter$1.tex
bibtex frontmatter$1.aux
xelatex frontmatter$1.tex
xelatex frontmatter$1.tex
