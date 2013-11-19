#!/usr/bin/perl

use strict;
use utf8;
use Encode;
use Unicode::Normalize;

use DBI;
use CGI::Carp qw/fatalsToBrowser/;

binmode(STDOUT, ":utf8");
print "Content-Type:text/plain; charset=UTF-8";

print "\r\n\r\n";

my $wrapped;

my $dbh = connectdb();

print 'Counting distinct forms for fascicle on ' . scalar(localtime) . "...\n";

for my $section (1..9) { # chapter sections
	print "$section. "
		. $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `chapter` = '9.$section'#)
		. "\n";
	my $sections = $dbh->selectall_arrayref(
		qq#SELECT tag, printseq, protoform, protogloss, plg,
					notes, xrefs, allofams, possallo
			FROM `etyma`
			WHERE `chapter` = '9.$section'
			ORDER BY `sequence`#);# AND tag=3487
	
	foreach (@$sections) {
		# print heading
		my ($tag, $printseq, $protoform, $protogloss, $plg,
				$notes, $xrefs, $allofams, $possallo) = map {NFC(decode_utf8($_))} @$_;
		$plg = $plg ne 'IA' ? '' : "($plg)";

		$protoform =~ s/⪤ +/⪤ */g;
		printf " %-6s%-30s", "($printseq)", "*$protoform $plg";

		# count forms
		my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT SUBSTRING(languagegroups.grpno,1,1), grp, language, lexicon.rn, 
       analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid
  FROM lexicon, languagenames, languagegroups, lx_et_hash
  WHERE (lx_et_hash.tag = $tag
    AND lx_et_hash.rn=lexicon.rn
    AND languagenames.lgid=lexicon.lgid
    AND languagenames.grpid=languagegroups.grpid)
  ORDER BY 1, languagenames.lgsort, language, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
		my $recs = $dbh->selectall_arrayref($sql);
		for my $rec (@$recs) {
			$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
		}
		
		# consolidate identical forms
		my $lastrec = $recs->[0];
		my $deletedforms = 0;
		for (1..$#$recs) {
			my ($grpno,$grp,  $lg,    $rn,   $an,   $form, $gloss,
				$srcabbr,$srcid)        = @{$recs->[$_]};
			my (undef, undef, $oldlg, undef, undef, $oldform, $oldgloss,
				$oldsrcabbr, $oldsrcid) = @$lastrec;
			if ($lg eq $oldlg
				&& eq_reflexes($oldform, $form)) {
				$deletedforms++;
			} else {
				$lastrec = $recs->[$_];
			}
		}
		
		printf "%3d ", scalar(@$recs)-$deletedforms;

		$wrapped = 0;
		my $s = sprintf("[#%-4s", $tag);
		wrapappend($s, " $protogloss");
# 		wrapappend($s, "; $notes") if $notes;
# 		wrapappend($s, "; xrefs: $xrefs") if $xrefs;
# 		wrapappend($s, "; ⪤ $allofams") if $allofams;
# 		wrapappend($s, "; ↭ $possallo") if $possallo;
		$s .= "]\n";
		
		print $s;
	}
}

$dbh->disconnect;

sub wrapappend {
	my $s = $_[1];
	for (split /(?<= )/, $s) {
		if (length($_[0]) > 48 && !$wrapped) {
			$_[0] .= "\n" . (' ' x 48);
			$wrapped = 1;
		}
		$_[0] .= $_;
	}
}

# special functions to combine similar records
sub eq_reflexes {
	my ($a, $b) = @_;
	$a =~ tr/+ .,;~◦⪤-//d;
	$b =~ tr/+ .,;~◦⪤-//d;
	return $a eq $b;
}

# Returns a database connection
sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'root';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
			 "$db_password",
			 {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}