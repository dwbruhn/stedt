#!/usr/bin/perl

# extract.pl
# by Dominic Yu
# 2011.02.03
#
# ...thoroughly hacked in details to support two-column output, and other features.
# jbl 2013
#
# see USAGE, below.
#

use lib '..';

use strict;
use utf8;
use Encode;
use Unicode::Normalize;
use SyllabificationStation;
use FascicleXetexUtil;
use STEDTUtil;
use Template;

my $INTERNAL_NOTES = 0;
my $ETYMA_TAGS = 0;
my $author = '';
if ($ARGV[-1] =~ /^--i/) {
	pop @ARGV;
	$INTERNAL_NOTES = 1;
	$ETYMA_TAGS = 1;
	$author = 'DRAFT';
}
my ($vol, $fasc, $chap) = map {/([\dxX]+)/} @ARGV;

unless ($vol && $fasc) {
	print <<USAGE;
Usage: $0 <volume> <fascicle> [<chapter>] [--i(nternal-notes)]
Output: one complete XeLaTeX file in the "tex" directory
Requires: various template files in the "tt" directory
USAGE
	exit;
}

my $dbh = STEDTUtil::connectdb();
my $syls = SyllabificationStation->new();
binmode(STDERR, ":utf8");

my ($date, $shortdate);
{
	my @date_items = (localtime)[3..5];
	@date_items = reverse @date_items;
	$date_items[0] += 1900;
	$date_items[1]++;
	$date = sprintf "%04i.%02i.%02i", @date_items;
	$shortdate = sprintf "%04i%02i%02i", @date_items;
}

my %tag2info; # this is (and should only be) used inside xml2tex, for looking up etyma refs

my @texfilenames;
my $mastertexfilename = "$vol-$fasc-$chap-master.tex";
$mastertexfilename =~ tr/A-Z/a-z/;
my $mastertitle;
my $masterVFC;

my $query = "SELECT * FROM chapters WHERE ";
$query .= " v = $vol ";
$query .= $fasc eq 'x' ? '' : " AND  f = $fasc ";
$query .= $chap eq 'x' ? '' : " AND  c = $chap ";

$query .= ' ORDER BY v,f,c,s1,s2,s3';

my $sectioncount = 0;

print STDERR "q: $query\n";
for (@{$dbh->selectall_arrayref($query)}) {
	my ($semkey,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info) = map {decode_utf8($_)} @$_;
	$sectioncount++;
	print STDERR "== $sectioncount ::: $semkey: $chaptertitle\n";

my $vol  = $v == 0 ? 'x' : $v;
my $fasc = $f == 0 ? 'x' : $f;
my $chap = $c == 0 ? 'x' : $c;
my $s1   = $s1 == 0 ? 'x' : $s1;
my $s2   = $s2 == 0 ? 'x' : $s2;
my $s3   = $s3 == 0 ? 'x' : $s3;

my $semkey = "$vol.$fasc.$chap.$s1.$s2.$s3";
$semkey    =~ s/\.x//g;
my $texfilename = "$vol-$fasc-$chap-$s1-$s2-$s3";
$texfilename =~ tr/A-Z/a-z/;
$texfilename =~ s/\-x//g;

if ($sectioncount == 1) {
  $mastertitle = escape_tex($chaptertitle);
  $masterVFC = $semkey;
}

# add warning about unsequenced items
my $hidden_etyma = $dbh->selectall_arrayref(
	qq#SELECT e.chapter,e.tag, e.protoform, e.protogloss, languagegroups.plg 
		FROM `etyma` AS `e` LEFT JOIN languagegroups ON e.grpid=languagegroups.grpid
		WHERE e.uid=8 AND concat(e.chapter,'.') LIKE '$semkey.%' AND e.sequence < 1#);
if (@$hidden_etyma && !$INTERNAL_NOTES) {
	print STDERR "Warning: The following etyma have a sequence number of 0\nand will not be included:\n";
	for my $e (@$hidden_etyma) {
		print STDERR join("\t", map {decode_utf8($_)} @$e), "\n";
	}
	#print "Do you want to continue? [Y/n] ";
	#if (<STDIN> =~ /^n/i) {
	#	exit(1);
	#}
}
undef $hidden_etyma; # no such thing anymore!

# build etyma hash
print STDERR "building etyma data...\n";
$vol  = "\\d+" if ($vol  eq "x");
$fasc = "\\d+" if ($fasc eq "x");
$chap = "\\d+" if ($chap eq "x");
my $chapterkey = $semkey;
print ">>> $semkey\n";
my $nextseq = 1;
for (@{$dbh->selectall_arrayref("SELECT tag,chapter,sequence,protoform,protogloss FROM etyma")}) {
	my ($tag,$chapter,@info) = map {decode_utf8($_)} @$_;
	#print ">>> $tag $chapter\n";
	if ($chapter =~ /^1.9.\d$/) {
		push @info, 'TBRS'; # "volume" info to print for cross refs in the notes
	} elsif ($chapter = $chapterkey) {
	        #print ">>> $tag $chapter\n";
		$info[0] = ''; # make sequence empty if not in the current extraction
	}
	$info[1] = '*' . $info[1];
	$info[1] =~ s/⪤} +/⪤} */g;
	$tag2info{$tag} = \@info;
}
$FascicleXetexUtil::tag2info = \&_tag2info;

my $title = $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `semkey` = '$semkey'#);
$title = escape_tex($title);
my $flowchartids = $dbh->selectcol_arrayref("SELECT noteid FROM notes WHERE spec='C' AND id='$semkey' AND notetype='G'");
print STDERR "generating VFC $semkey :: '$title'...\n";
my $chapter_notes = [map {xml2tex(decode_utf8($_))} @{$dbh->selectcol_arrayref(
	"SELECT xmlnote FROM notes WHERE spec='C' AND id='$semkey' AND notetype = 'T' ORDER BY ord")}
	];

my @etyma; # array of infos to be passed on to the template
my $extra_where = ($INTERNAL_NOTES ? "" : "AND e.sequence >= 1");  # extra condition to exclude unsequenced etyma when this is a non-draft version
my $etyma_in_chapter = $dbh->selectall_arrayref(
	qq#SELECT e.tag, e.sequence, e.protoform, e.protogloss, languagegroups.plg
		FROM `etyma` AS `e` LEFT JOIN languagegroups ON e.grpid=languagegroups.grpid
		WHERE e.uid=8 AND status != 'DELETE' AND e.chapter = '$semkey' $extra_where
		ORDER BY e.sequence#);

print STDERR (scalar @$etyma_in_chapter) . " etyma in this chapter\n";
next if 0 == scalar @$etyma_in_chapter; # skip entire chapter if it has no etyma.
foreach (@$etyma_in_chapter) {
	my %e; # hash of infos to be added to @etyma

	# heading stuff
	@e{qw/tag seq protoform protogloss plg/}
		= map {escape_tex(decode_utf8($_))} @$_;

	# mess with sequence number if its an "autosequence" number...
	#print STDERR "before nextseq $nextseq :: " . int($e{seq}) . "\n";
	$nextseq = int($e{seq}) if (int($e{seq}) < 1000);
	$e{seq} = $nextseq if (int($e{seq}) >= 1000);
	$nextseq++;
	#print STDERR "after nextseq $nextseq :: " . int($e{seq}) . "\n";

	# prettify sequence number
	$e{seq} =~ s/\.0$//;
	$e{seq} =~ s/\.(\d)/chr(96+$1)/e;

	# $e{plg} = '' unless $e{plg} eq 'IA';
	$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";

	$e{protoform} = format_protoform($e{protoform});
	$e{protoform_text} = $e{protoform};
	#$e{protoform_text} =~ s/\\STEDTU{⪤}/⪤/g; # make hyperref stop complaining about "Token not allowed in a PDFDocEncoded string"

	# make protoform pretty
	$e{protoform} = prettify_protoform($e{protoform}); # make vertical

	$e{mesoroots} = $dbh->selectall_arrayref("SELECT grpno,grp,plg,form,gloss FROM mesoroots
		LEFT JOIN languagegroups USING (grpid)
		WHERE mesoroots.tag=$e{tag} ORDER BY grp0,grp1,grp2,grp3,grp4,variant", {Slice=>{}});

	# etymon notes
	$e{notes} = [];
	$e{subgroupnotes} = [];
	foreach (@{$dbh->selectall_arrayref("SELECT notetype, xmlnote, grpno, grp FROM notes
			LEFT JOIN languagegroups ON (notes.id = languagegroups.grpid)
			WHERE tag=$e{tag} AND notetype != 'F' ORDER BY grp0,grp1,grp2,grp3,grp4,ord")}) {
		my ($notetype, $xmlnote, $grpno, $grp) = @$_;
		next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
		if ($grpno) {
			push @{$e{subgroupnotes}}, {grpno=>$grpno, grp=>$grp, type=>$notetype, text=>xml2tex(decode_utf8($xmlnote))};
		} else {
			push @{$e{notes}}, {type=>$notetype, text=>xml2tex(decode_utf8($xmlnote))};
		}
	}


	# do entries
	my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT languagegroups.grpno, grp, language, lexicon.rn, 
   (SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
   reflex, gloss, gfn, languagenames.srcabbr, lexicon.srcid, notes.rn
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = $e{tag}
AND lx_et_hash.rn=lexicon.rn AND lx_et_hash.uid=8
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid)
ORDER BY languagegroups.grp0, languagegroups.grp1, languagegroups.grp2, languagegroups.grp3, languagegroups.grp4, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
	my $recs = $dbh->selectall_arrayref($sql);
	print STDERR "#$e{tag}: ($e{seq}) ";
	if (@$recs) { # skip if no records
		for my $rec (@$recs) {
			$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
		}
		print STDERR "  " . scalar(@$recs) . " records. ";
		
		# we must make two passes through the data here:
		# 1. consolidate identical forms
		my $lastrec = $recs->[0];
		my $deletedforms = 0;
		for (1..$#$recs) {
			my ($grpno,$grp,  $lg,    $rn,   $an,   $form, $gloss,
				$gfn,    $srcabbr,    $srcid,$notern)        = @{$recs->[$_]};
			my (undef, undef, $oldlg, undef, undef, $oldform, $oldgloss,
				$oldgfn, $oldsrcabbr, $oldsrcid) = @$lastrec;
			$gfn =~ s/\.$//;	# remove any trailing period from gfn
			$oldgfn =~ s/\.$//;
			if ($lg eq $oldlg && $gfn eq $oldgfn # note: the gfn comparison needs to be made more sophisticated
				&& eq_reflexes($oldform, $form)) {
				$recs->[$_][2] = ''; # mark as empty for skipping later
				$lastrec->[6] = merge_glosses($oldgloss,$gloss);
				$lastrec->[8] .= ";\\citealt{$srcabbr}";
				$lastrec->[9] .= ";$srcid";
				
				if ($notern) {
					$lastrec->[10] .= ',' if $lastrec->[10];
					$lastrec->[10] .= $notern;
				}
	
				$deletedforms++;
			} else {
				$lastrec = $recs->[$_];
			}
		}
		
		# 2. print the forms
		print STDERR "  " . ((scalar(@$recs)-$deletedforms) . " distinct forms.") if $deletedforms;
		my $text;
		$text .= "{\\small\n";
		$text .= "\\fascicletablebegin\n";
		
		my $lastgrpno = '';
		my $lastlg = '';
		my $group_space = '[0.5ex]';
		for my $rec (@$recs) {
			my ($grpno,$grp,$lg,$rn,$an,$form,$gloss,$gfn,$srcabbr,$srcid,$notern)
				= @$rec;
			next unless $lg; # skip duplicate forms (see above)
			
			if ($grpno ne $lastgrpno) {
				$text .= '[1ex]' unless $lastgrpno eq ''; # add space above this row
				my ($tmp_grpno, $grpname);
				while (@{$e{mesoroots}} && $e{mesoroots}[0]{grpno} lt $grpno
						|| @{$e{subgroupnotes}} && $e{subgroupnotes}[0]{grpno} lt $grpno) {
					if (@{$e{mesoroots}} && @{$e{subgroupnotes}} or @{$e{mesoroots}}) {
						$tmp_grpno = $e{mesoroots}[0]{grpno};
						$grpname   = $e{mesoroots}[0]{grp};
					} else {
						$tmp_grpno = $e{subgroupnotes}[0]{grpno};
						$grpname   = $e{subgroupnotes}[0]{grp};
					}
					my ($meso, $note) = get_meso_notes($e{mesoroots}, $e{subgroupnotes}, $tmp_grpno);
					$text .= "\\multicolumn{4}{>{\\hangindent=.8in}p{5.7in}}{$tmp_grpno. $grpname";
					$text .= $meso;
					$text .= '}&';
					$text .= $note;
					$text .= "\\\\*$group_space\n";
				}
				my ($meso, $note) = get_meso_notes($e{mesoroots}, $e{subgroupnotes}, $grpno);
				$text .= "\\multicolumn{4}{>{\\hangindent=.8in}p{5.7in}}{\\textsc{$grpno. $grp}";
				$text .= $meso;
				$text .= '}&';
				$text .= $note;
				$text .= "\\\\*$group_space\n"; # if the star doesn't work, use \\nopagebreak before the \n
				$lastgrpno = $grpno;
			}
			
			
			$syls->fit_word_to_analysis($an, $form);
			$form = $syls->get_brace_mark_cog($e{tag}) || $form;
			$form =~ s/(\S)=(\S)/$1꞊$2/g; # short equals - must be done AFTER syllabification station			
			$form =~ s/{/\\textbf{/g;
			$form = '*' . $form if ($lg =~ /^\*/); # put * for proto-lgs
			if ($lg eq $lastlg) {
				$lg = '';			# don't repeat the lg name if same
			} else {
				$lastlg = $lg;
			}
			$lg = escape_tex($lg);
			$lg = '{}' . $lg if $lg =~ /^\*/; # need curly braces to prevent \\* treated as a command!
			$lg = '\\textit{' . $lg . '}';
			$gfn =~ s/\.$//;	# remove any trailing period from gfn to avoid double periods
			my $gloss_string = ($gfn) ? "$gloss ($gfn.)" : $gloss; # concatenate with gfn if it's not empty
			$text .= join(' &', $lg, escape_tex(      $form      ,1),
				escape_tex($gloss_string), src_concat("\\citealt{$srcabbr}", $srcid), '');	# extra slot for footnotes...
			
			# footnotes, if any
			if ($notern) {
				$notern = join(' or ', map {"`rn`=$_"} split /,/, $notern);
				# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
				my @results = @{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
						. "WHERE $notern AND (`id`=$e{tag} OR `id`='') ORDER BY ord")};
				for my $rec (@results) {
					my ($notetype, $note) = @$rec;
					next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
					#$text .= "\\raisebox{-0.5ex}{\\footnotemark}";	# lower footnotes so they're less ambiguous about being on its line
					#$text .= '\\footnotetext{';
					$text .= '\\footnote{';
					$text .= '\\textit{' if $notetype eq 'I'; # [Internal] 
					$text .= '[Orig/Source] ' if $notetype eq 'O';
					$text .= xml2tex(decode_utf8($note));
					$text .= '}' if $notetype eq 'I';
					$text .= "}\n";
				}
			} elsif ($ETYMA_TAGS) {
				$text .= "\\hspace*{1ex}";
			}
			if ($ETYMA_TAGS && $an && $an ne $e{tag} && $an ne "$e{tag},$e{tag}") {
				# for internal purposes, print out analysis 
				$an =~ s/\b$e{tag}\b/\\textasciitilde/g;
				$text .= "{\\tiny $an}";
			}
			
			$text .= "\\\\\n";
		}
		$text .= "\\end{mpsupertabular}\n" unless $lastgrpno eq ''; # if there were no forms, skip this
		$text .= "}\n\n";
		#$text .= "\n\n";
		$e{records} = $text;
		print STDERR "\n";
	} else {
		$e{records} = '';
		# set this explicitly so Template doesn't reuse the value from
		# the previous iteration of the loop. (This reuse is side effect of how
		# TT handles FOREACH directives when not specifying a target variable,
		# which is the case for this particular loop in the template.)
		print STDERR "skipped, no records\n";
	}



	# Chinese comparanda
	$e{comparanda} = [];
	my @comparanda = @{$dbh->selectcol_arrayref("SELECT xmlnote FROM notes WHERE tag=$e{tag} AND notetype = 'F'")};
	for my $note (@comparanda) {
		$note = decode_utf8($note);
		# $note =~ s/’ /’\n\n/; # not /g, only the first instance WHY
		$note =~ s/{/\\{/g; $note =~ s/}/\\}/g; # convert curly braces here.
		$note =~ s/(Karlgren|Li|Baxter): /\\hfill $1: /g;
		$note =~ s/ Citations:/\n\nCitations:/g;
		$note =~ s/ Correspondences:/\n\nCorrespondences:/g;
		$note =~ s/(\[ZJH\])/\\hfill $1/g;
		$note =~ s/(\[JAM\])/\\hfill $1/g;
		push @{$e{comparanda}}, xml2tex($note,1); # don't convert curly braces
	}
# saving the best for last ... include this etymon if it has some reflexes, or if it's a draft (but has no reflexes)
push @etyma, \%e if ((scalar(@$recs) > 0) || $INTERNAL_NOTES);
}

# print rootlets
# my $chapter_end_notes = $dbh->selectcol_arrayref(
# 	"SELECT xmlnote FROM notes WHERE spec='C' AND id='$semkey' AND notetype = 'F' ORDER BY ord");
# if (@$chapter_end_notes) {
# 	print "\\begin{center} * * * \\end{center}\n\n";
# }
# for my $note (@{$chapter_end_notes}) {
# 	print xml2tex(decode_utf8($note)) . "\n\n";
# }

my $tt = Template->new() || die "$Template::ERROR\n";
$tt->process("tt/chapter.tt", {
	semkey   => $semkey,
	volume   => $vol,
	fascicle => $fasc,
	chapter  => $chap,
	date     => $date,
	title    => $title,
	author   => $author,
	flowchartids => $flowchartids,
	chapter_notes => $chapter_notes,
	etyma    => \@etyma,
	internal_notes => $INTERNAL_NOTES,

}, "tex/${texfilename}.tex", binmode => ':utf8' ) || die $tt->error(), "\n";
push @texfilenames,$texfilename;
}

my $tt = Template->new() || die "$Template::ERROR\n";
$tt->process("tt/master.tt", {
	semkey   => $masterVFC,
	date     => $date,
	xtitle    => $mastertitle,
	author   => $author,
	texfilenames => \@texfilenames,

}, "tex/${mastertexfilename}", binmode => ':utf8' ) || die $tt->error(), "\n";


$dbh->disconnect;
print STDERR "done!\n";

sub _tag2info {
	my ($t, $s) = @_;
	my $a_ref = $tag2info{$t};
	return "\\textit{[ERROR! Dead etyma ref #$t!]}" unless $a_ref;
	my ($seq, $pform, $pgloss, $volume) = @{$a_ref};
	if ($seq) { # if the root is in current extraction, put the print ref
		$seq =~ s/\.0$//;
		$seq =~ s/\.(\d)/chr(96+$1)/e;
		$t = "($seq)";
		$t = "$volume $t" if $volume;
	} else {
		$t = $ETYMA_TAGS ? "\\textit{\\tiny[#$t]}" : ''; # don't escape the # symbol here, it will be taken care of by escape_tex
	}
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

sub format_protoform {
	my $s = shift;
	for ($s) {
		s/⪤} +/⪤} */g;
		s/ OR +/ or */g;
		s/\\textasciitilde\\ +/\\textasciitilde */g;
		s/ = +/ = */g;
		s/^/*/;
		s/(\*\S+)/\\textbf{$1}/g; # bold only the protoform, not allofam or "or"
	}
	return $s;
}

# given list of mesoroots and subgroupnotes, pull out everything belonging
# to the present grpno from the front of the lists
sub get_meso_notes {
	my ($mesos, $notes, $grpno) = @_;
	my @m;
	while (@$mesos && $mesos->[0]{grpno} eq $grpno) {
		push @m, shift @$mesos;
	}
	my $meso_string = '';
	if (@m) {
		$meso_string = ": $m[0]{plg} ";
	}
	$meso_string .= join ', ', map {format_protoform(escape_tex(decode_utf8($_->{form}))) . ' ' . escape_tex(decode_utf8($_->{gloss}))} @m;
	my $notes_string = '';
	while (@$notes && $notes->[0]{grpno} eq $grpno) {
		my ($notetype, $note) = ($notes->[0]{type}, $notes->[0]{text});
		shift @$notes;
		next if $notetype eq 'I' && !$INTERNAL_NOTES;
		#$notes_string .= "\\raisebox{-0.5ex}{\\footnotemark}";
		#$notes_string .= '\\footnotetext{';
		$notes_string .= '\\footnote{';
		$notes_string .= '\\textit{' if $notetype eq 'I';
		$notes_string .= $note;
		$notes_string .= '}' if $notetype eq 'I';
		$notes_string .= "}\n";
	}
	return $meso_string, $notes_string;
}
