#!/usr/bin/perl
# lglist.pl
# by Daniel Bruhn
# 2014.06.07
#
# extracts list of languages (+associated subgroups and srcabbrs) with STEDT-tagged records
# creates table for inclusion in STEDT backmatter

use lib '..';

use strict;
use utf8;
use Encode;
use FascicleXetexUtil;
use STEDTUtil;
use Template;

my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");
binmode(STDOUT, ":utf8");

my $query = "SELECT grp, grpno, languagenames.language, GROUP_CONCAT(DISTINCT srcabbr)
		FROM lexicon
		JOIN lx_et_hash ON (lexicon.rn=lx_et_hash.rn AND lx_et_hash.uid=8 AND lx_et_hash.tag!=0)
		JOIN languagenames USING (lgid)
		LEFT JOIN languagegroups USING (grpid)
		GROUP BY languagenames.language
		ORDER BY grp0,grp1,grp2,grp3,grp4,languagenames.language";

my ($grp,$grpno,$lg,$srcabbrs);
my $prev_grp = "";

print "{\\small\n";
print '\\begin{supertabular}{@{\\hspace*{1.1em}}>{\\hangindent=.1in}p{2in} p{5in}}' . "\n";


for (@{$dbh->selectall_arrayref($query)}) {
	($grp,$grpno,$lg,$srcabbrs) = map {decode_utf8($_)} @$_;
	
	$grp =~ s/"/``/;	# hack to fix double quotes; change first quote to TeX left double quote
	$lg =~ s/"/``/;
	
	# if new group name, print on its own lline
	if ($grp ne $prev_grp) {
		print "\\multicolumn{2}{l}{\\textsc{" . escape_tex($grpno) . ".\ " . escape_tex($grp) . "}} \\\\*[1ex]\n";
	}
	$prev_grp = $grp;
	
	# language
	print "\\textit{${\escape_tex($lg)}} & ";	# do some fancy perl magic to make a function call inside a double-quoted string
	
	# split srcabbrs by commas, surround each with \citealt{}, then re-join by commas and output
	print join(', ', (map {"\\citealt{$_}"} split(',', $srcabbrs)));
	
	print "\\\\[0.5ex]\n";
}

print "\\end{supertabular}\n}";