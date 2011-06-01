#! /bin/bash
# use -rtvni to do a dry run with itemized changes

rsync -rtv --exclude '.svn' --exclude 'js' ~/rootcanal/web/ ~/public_html
rsync -rtv --exclude '.svn' ~/rootcanal/perl/STEDT/ ~/pm/STEDT
# add new files to js directory if necessary, but let minify do the replacing
rsync -rtv --exclude '.svn' --ignore-existing --delete ~/rootcanal/web/js/ ~/public_html/js
find ~/rootcanal/web/js/ -name "*.js" -exec perl ~/rootcanal/deployment/minify.pl {} \;
