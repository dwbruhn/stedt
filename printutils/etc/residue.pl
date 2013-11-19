#!/usr/bin/perl

# find untagged records of the skin type

use strict;
use utf8;
use Encode;
use FascicleXetexUtil;
use EtymaSets; # for group names
use STEDTUtil;

my $INTERNAL_NOTES = 1;
my $ETYMA_TAGS = 1;

binmode(STDOUT, ":utf8");

my $dbh = STEDTUtil::connectdb();
my %groupno2name = EtymaSets::groupno2name($dbh);
my ($string_of_glosses) = @ARGV[0];
my @glosses = split(",",$string_of_glosses);

print "glosses",$string_of_glosses;
# build etyma hash
my %tag2info;  # this should only be used inside xml2tex, for looking up etyma refs
for (@{$dbh->selectall_arrayref("SELECT tag,chapter,sequence,protoform,protogloss FROM etyma")}) {
	my ($tag,$chapter,@info) = map {decode_utf8($_)} @$_;
	$info[0] = ''; # make printseq empty
	$info[1] = '*' . $info[1];
	$info[1] =~ s/⪤} +/⪤} */g;
	$tag2info{$tag} = \@info; # @info has printseq,protoform,protogloss
}
$FascicleXetexUtil::tag2info = \&_tag2info;

# {
# 	my @date_items = (localtime)[3..5];
# 	@date_items = reverse @date_items;
# 	$date_items[0] += 1900;
# 	$date_items[1]++;
# 	printf "\\date{%04i.%02i.%02i}\n", @date_items;
# }

open my $tmp_fh, ">:utf8", "tex/untagged.tex" or die $!;
select $tmp_fh; # set default for print
print STDERR "generating...\n";

my @badtags = qw(
3456 782 596 448 782 596 448 784 792 593 586 585 589 588
595 590 783 591 781 785 794 790 780 594 795 592
);
my $other_tags = ''; # join ' AND ', map {"analysis NOT RLIKE '[[:<:]]$_" . '[[:>:]]\''} @badtags;

#my @glosses = qw(
#	sit
#); # bark hide foreskin eyelid lip scales scalp, peel, shell
my $glosses = join ' OR ', map {"gloss RLIKE '[[:<:]]$_'"} @glosses;

print join ' ', @glosses;
print " - all \\today\n\n";

# do entries
my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT languagegroups.ord, grp, language, lexicon.rn, 
'' as analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, notes.rn
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups
WHERE (languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid
AND ($glosses)
)
ORDER BY languagegroups.ord, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL

#print STDERR $sql;

my $recs = $dbh->selectall_arrayref($sql);
if (@$recs) { # skip if no records
	for my $rec (@$recs) {
		$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
	}
	
	print STDERR scalar(@$recs) . " records.\n";
	
	# we must make two passes through the data here:
	# 1. consolidate identical forms
	my $lastrec = $recs->[0];
	my $deletedforms = 0;
	for (1..$#$recs) {
		my ($grpno,$grp,  $lg,    $rn,   $an,   $form, $gloss,
			$srcabbr,$srcid,$notern)        = @{$recs->[$_]};
		my (undef, undef, $oldlg, undef, $oldan, $oldform, $oldgloss,
			$oldsrcabbr, $oldsrcid) = @$lastrec;
		if ($lg eq $oldlg && $an eq $oldan
			&& eq_reflexes($oldform, $form)) {
			$recs->[$_][2] = ''; # mark as empty for skipping later
			$lastrec->[6] = merge_glosses($oldgloss,$gloss);
			$lastrec->[7] .= ";$srcabbr";
			$lastrec->[8] .= ";$srcid";
			
			if ($notern) {
				$lastrec->[9] .= ',' if $lastrec->[9];
				$lastrec->[9] .= $notern;
			}
	
			$deletedforms++;
		} else {
			$lastrec = $recs->[$_];
		}
	}
	
	# 2. print the forms
	### print((scalar(@$recs)-$deletedforms) . " distinct forms.") if $deletedforms;
	print "\n\n";
	print "{\\footnotesize\n";
	print "\\fascicletablebegin\n";
	
	my $lastgrpno = '';
	my $lastlg = '';
	my $group_space = '[0.5ex]';
	for my $rec (@$recs) {
		my ($grpno,$grp,$lg,$rn,$an,$form,$gloss,$srcabbr,$srcid,$notern)
			= @$rec;
		next unless $lg; # skip duplicate forms (see above)
		
		if ($grpno ne $lastgrpno) {
			# print "\\end{longtable}\n" unless $lastgrpno eq '';
			# print "$groupno2name{$grpno}\\setlength{\\parskip}{0ex}\\nopagebreak[4]\n\n";
			#print "\\fascicletablebegin\n";
			print '[1ex]' unless $lastgrpno eq ''; # add space above this row
			print "\\multicolumn{5}{l}{$groupno2name{$grpno}}\\\\*$group_space\n"; # if the star doesn't work, use \\nopagebreak before the \n
			$lastgrpno = $grpno;
		}
		else {
			print "\\hline ";
		}
	
		$form =~ s/(\S)=(\S)/$1$2/g;
		$form = '*' . $form if ($lg =~ /^\*/); # put * for proto-lgs
		if ($lg eq $lastlg) {
			$lg = '';			# don't repeat the lg name if same
		} else {
			$lastlg = $lg;
		}
		$lg = escape_tex($lg);
		$lg = '{}' . $lg if $lg =~ /^\*/; # need curly braces to prevent \\* treated as a command!
		print join(' &', $lg, escape_tex(      $form      ,1),
			$gloss, src_concat($srcabbr, $srcid), '');	# extra slot for footnotes...
		
		# footnotes, if any
		if ($notern) {
			$notern = join(' or ', map {"`rn`=$_"} split /,/, $notern);
			my @results = @{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
					. "WHERE $notern ORDER BY ord")};
			for my $rec (@results) {
				my ($notetype, $note) = @$rec;
				next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
				print "\\raisebox{-0.5ex}{\\footnotemark}";	# lower footnotes so they're less ambiguous about being on its line
				print '\\footnotetext{';
				print '\textit{' if $notetype eq 'I';
				print '[Orig/Source] ' if $notetype eq 'O';
				print xml2tex(decode_utf8($note));
				print '}' if $notetype eq 'I';
				print "}\n";
			}
		} elsif ($ETYMA_TAGS) {
			print "\\hspace*{1.5ex}";
		}
		if ($ETYMA_TAGS && $an) { # for internal purposes, print out analysis 
			print "{\\tiny $an}";
		}
		
		print  "\\\\\n";
	}
	print "\\end{longtable}\n" unless $lastgrpno eq ''; # if there were no forms, skip this
	print "}\n\n";
}

select STDOUT; # restore it, just for good form
close $tmp_fh or die $!;


$dbh->disconnect;
print STDERR "done!\n";

sub _tag2info {
	my ($t, $s) = @_;
	my $a_ref = $tag2info{$t};
	return "\\textit{[ERROR! Dead etyma ref #$t!]}" unless $a_ref;
	my ($printseq, $pform, $pgloss) = @{$a_ref};
	$t = $ETYMA_TAGS ? "\\textit{\\tiny[#$t]}" : ''; # don't escape the # symbol here, it will be taken care of by escape_tex
	if ($s =~ /^\s+$/) { # empty space means only put the number, no protogloss
		$s = '';
	} else {
		$pform =~ s/-/‑/g; # non-breaking hyphens
		$pform =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
		$pform =~ s/(\*\S+)/\\textbf{$1}/g; # bold the protoform but not the allofam sign or gloss
		if ($s) {			# alternative gloss, add it in
			$s = "$pform $s";
		} else {
			$s = "$pform $pgloss"; # put protogloss if no alt given
		}
		$s = " $s" if $t; # add a space between if there's a printseq
	}
	return "\\textbf{$t}$s";
}
