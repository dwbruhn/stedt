#!/usr/bin/perl
# srcnotes.pl
# by Daniel Bruhn
# 2014.09.04
#
# extracts notes on bibliographic sources
# creates pages for inclusion in STEDT backmatter
# note that hyperlinks (especially with tildes) and underscores are problematic
#
# for inclusion:
# put this command in shebang.sh: perl srcnotes.pl > srcnotes.tex
# include these lines in masterTemplate.tex after the References section:

# \cleardoublepage
# \phantomsection
# \fancyhead[LE]{\Large{Bibliographic Notes} \vspace{0.5em}}
# \fancyhead[RO]{\Large{Bibliographic Notes} \vspace{0.5em}}
# \addcontentsline{toc}{part}{Bibliographic Notes}
# \chapter*{Bibliographic Notes}
# \input{srcnotes}

use lib '..';

use strict;
use utf8;
use Encode;
use FascicleXetexUtil;
use STEDTUtil;

my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $query = "SELECT notes.id,notes.xmlnote
		FROM notes
		LEFT JOIN srcbib ON notes.id=srcbib.srcabbr
		WHERE spec='S' AND notetype!='I'
		ORDER BY srcbib.author,srcbib.year,notes.id,notes.ord";

my ($src,$note);
my $prev_src = "";

# loop through all notes
for (@{$dbh->selectall_arrayref($query)}) {
	($src,$note) = map {decode_utf8($_)} @$_;
	
#	next if $src eq 'LFW1997';	# skip this note until we figure out what to do with underscores
	
	$note =~ s/_/\\_/g; # escape underscores
	
	$note = xml2tex($note);

	# if new source, print citation
	if ($src ne $prev_src) {
		print "\n\n\\subsection*{\\citealt*{$src}}\n\n";
	}
	$prev_src = $src;
	
	# note
	print "\n$note";

}


