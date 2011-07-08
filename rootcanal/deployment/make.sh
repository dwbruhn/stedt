#! /bin/bash
# use -rtvni to do a dry run with itemized changes

svn up ~/svn-rootcanal
rsync -rtv --exclude '.svn' --exclude 'js' ~/svn-rootcanal/web/ ~/public_html
rsync -rtv --exclude '.svn' ~/svn-rootcanal/perl/STEDT/ ~/pm/STEDT
# add new files to js directory if necessary, but let minify do the replacing
rsync -rtv --exclude '.svn' --ignore-existing --delete ~/svn-rootcanal/web/js/ ~/public_html/js
find ~/svn-rootcanal/web/js/ -name "*.js" -exec perl ~/svn-rootcanal/deployment/minify.pl {} \;

svn info ~/svn-rootcanal | grep 'Revision' > ~/deployed.txt

