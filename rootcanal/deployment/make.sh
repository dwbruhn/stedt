#! /bin/bash
# use -rtvni to do a dry run with itemized changes

git pull -v
rsync -rti --exclude '.git*' --exclude 'js' --exclude 'scriptaculous/' --exclude 'admin.tt' ../web/ $1
rsync -rti --exclude '.git*' ../perl/STEDT/ $1/STEDT
# add new files to js directory if necessary, but let minify do the replacing
rsync -rti --exclude '.git*' --ignore-existing --delete ../web/js/ $1/js
rsync -rti --exclude '.git*' --ignore-existing --delete ../web/scriptaculous/ $1/scriptaculous/
find ../web/js/ -name "*.js" -exec perl minify.pl {} \;
find ../web/scriptaculous/*/ -name "*.js" -exec perl minify.pl {} \;

git log | grep commit | head -1 | cut -f2 -d" " > deployed.txt
perl -pe  's{<\!-- svnversion -->}{"<p>" . `git log | grep commit | head -1` . "</p>"}e' ../web/admin.tt > $1/admin.tt
