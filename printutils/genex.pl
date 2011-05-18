#!/usr/bin/perl

# extract.pl
# by Dominic Yu
# 2011.02.03
#
# see USAGE, below.
#
# to do: it ignores any "sections" (e.g. I.6.5.1)
#
# we need a better way to print out cross-references to roots that have
# already been published, e.g. in TBRS
#
# also, should synonym sets, multiple sections, etc. go in here?


use strict;
use utf8;
use Encode;
use Unicode::Normalize;
use SyllabificationStation;
use FascicleXetexUtil;
use EtymaSets;
use STEDTUtil;
use Template;

my $INTERNAL_NOTES = 0;
my $ETYMA_TAGS = 0;
if ($ARGV[-1] =~ /^--i/) {
	pop @ARGV;
	$INTERNAL_NOTES = 1;
	$ETYMA_TAGS = 1;
}
my ($vol, $fasc, $chap) = map {/(\d+)/} @ARGV;

unless ($vol && $fasc) {
	print <<USAGE;
Usage: $0 <volume> <fascicle> [<chapter>] [--i(nternal-notes)]
Output: one complete XeLaTeX file in the "tex" directory
Requires: various template files in the "tt" directory
USAGE
	exit;
}

my $dbh = STEDTUtil::connectdb();
my %groupno2name = EtymaSets::groupno2name($dbh);
my $syls = SyllabificationStation->new();
binmode(STDERR, ":utf8");

# build etyma hash
print STDERR "building etyma data...\n";
my %tag2info; # this is (and should only be) used inside xml2tex, for looking up etyma refs
for (@{$dbh->selectall_arrayref("SELECT tag,chapter,printseq,protoform,protogloss FROM etyma")}) {
	my ($tag,$chapter,@info) = map {decode_utf8($_)} @$_;
	if ($chapter =~ /^9.\d$/) {
		push @info, 'TBRS'; # "volume" info to print for cross refs in the notes
	} elsif ($chapter ne "$fasc.$chap") {
		$info[0] = ''; # make printseq empty if not in the current extraction
	}
	$info[1] = '*' . $info[1];
	$info[1] =~ s/⪤} +/⪤} */g;
	$tag2info{$tag} = \@info;
}
$FascicleXetexUtil::tag2info = \&_tag2info;


my ($date, $shortdate);
{
	my @date_items = (localtime)[3..5];
	@date_items = reverse @date_items;
	$date_items[0] += 1900;
	$date_items[1]++;
	$date = sprintf "%04i.%02i.%02i", @date_items;
	$shortdate = sprintf "%04i%02i%02i", @date_items;
}

if ($vol != 1) {
	print "Sorry, I don't know how to do anything other than body parts yet.\n";
	exit;
}

print STDERR "generating chapter $chap...\n";
my $title = $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `chapter` = '$fasc.$chap'#);
my $flowchartids = $dbh->selectcol_arrayref("SELECT noteid FROM notes WHERE spec='C' AND id='$fasc.$chap' AND notetype='G'");
my $chapter_notes = [map {xml2tex(decode_utf8($_))} @{$dbh->selectcol_arrayref(
	"SELECT xmlnote FROM notes WHERE spec='C' AND id='$fasc.$chap' AND notetype = 'T' ORDER BY ord")}
	];

my @etyma; # array of infos to be passed on to the template
my $etyma_in_chapter = $dbh->selectall_arrayref(
	qq#SELECT e.tag, e.printseq, e.protoform, e.protogloss, e.plg, e.hptbid, e.tag=e.supertag AS is_main
		FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag
		WHERE e.chapter = '$fasc.$chap' AND e.printseq != ''
		ORDER BY super.sequence, e.plgord#);


foreach (@$etyma_in_chapter) {
	my %e; # hash of infos to be added to @etyma
	push @etyma, \%e;

	# heading stuff
	@e{qw/tag printseq protoform protogloss plg hptbid is_main/}
		= map {escape_tex(decode_utf8($_))} @$_;
	# $e{plg} = '' unless $e{plg} eq 'IA';
	$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";

	$e{protoform} =~ s/⪤} +/⪤} */g;
	$e{protoform} =~ s/ OR +/ or */g;
	$e{protoform} =~ s/\\textasciitilde\\ +/textasciitilde\\ */g;
	$e{protoform} =~ s/ = +/ = */g;
	$e{protoform} = '*' . $e{protoform};
	$e{protoform} =~ s/(\*\S+)/\\textbf{$1}/g; # bold only the protoform, not allofam or "or"
		# perhaps better to use [^ ] instead of \S...
	$e{protoform_text} = $e{protoform};
	#$e{protoform_text} =~ s/\\STEDTU{⪤}/⪤/g; # make hyperref stop complaining about "Token not allowed in a PDFDocEncoded string"

	# make protoform pretty
	$e{protoform} = prettify_protoform($e{protoform}); # make vertical

	# etymon notes
	$e{notes} = [];
	my $seen_hptb; # don't generate an HPTB reference if there's a custom HPTB note already
	foreach (@{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
			. "WHERE tag=$e{tag} AND notetype != 'F' ORDER BY ord")}) {
		my $notetype = $_->[0];
		next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
		$seen_hptb = 1 if $notetype eq 'H';
		push @{$e{notes}}, {type=>$notetype, text=>xml2tex(decode_utf8($_->[1]))};
	}
	if ($e{hptbid} && !$seen_hptb) {
		my $text = "See \\textit{HPTB} ";
		my @refs = split /,/, $e{hptbid};
		my @strings;
		for my $id (@refs) {
			my ($pform, $plg, $pages) =
				$dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=?", undef, $id);
			$pform = decode_utf8($pform);
			my $p = ($pages =~ /,/ ? "pp" : "p");
			push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "\\textbf{$pform}, $p. $pages";
		}
		$text .= escape_tex(join('; ', @strings), 1);
		$text .= '.';
		push @{$e{notes}}, {type=>'H', text=>$text};
	}


	# do entries
	my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT languagegroups.ord, grp, language, lexicon.rn, 
   analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, notes.rn
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = $e{tag}
AND lx_et_hash.rn=lexicon.rn
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid)
ORDER BY languagegroups.ord, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
	my $recs = $dbh->selectall_arrayref($sql);
	if (@$recs) { # skip if no records
		for my $rec (@$recs) {
			$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
		}
		### print scalar(@$recs) . " records. ";
		
		# we must make two passes through the data here:
		# 1. consolidate identical forms
		my $lastrec = $recs->[0];
		my $deletedforms = 0;
		for (1..$#$recs) {
			my ($grpno,$grp,  $lg,    $rn,   $an,   $form, $gloss,
				$srcabbr,$srcid,$notern)        = @{$recs->[$_]};
			my (undef, undef, $oldlg, undef, undef, $oldform, $oldgloss,
				$oldsrcabbr, $oldsrcid) = @$lastrec;
			if ($lg eq $oldlg
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
		my $text;
		$text .= "{\\footnotesize\n";
		$text .= "\\fascicletablebegin\n";
		
		my $lastgrpno = '';
		my $lastlg = '';
		my $group_space = '[0.5ex]';
		for my $rec (@$recs) {
			my ($grpno,$grp,$lg,$rn,$an,$form,$gloss,$srcabbr,$srcid,$notern)
				= @$rec;
			next unless $lg; # skip duplicate forms (see above)
			
			if ($grpno ne $lastgrpno) {
				$text .= '[1ex]' unless $lastgrpno eq ''; # add space above this row
				$text .= "\\multicolumn{5}{l}{$groupno2name{$grpno}}\\\\*$group_space\n"; # if the star doesn't work, use \\nopagebreak before the \n
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
			$text .= join(' &', $lg, escape_tex(      $form      ,1),
				$gloss, src_concat($srcabbr, $srcid), '');	# extra slot for footnotes...
			
			# footnotes, if any
			if ($notern) {
				$notern = join(' or ', map {"`rn`=$_"} split /,/, $notern);
				# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
				my @results = @{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
						. "WHERE $notern AND (`id`=$e{tag} OR `id`='') ORDER BY ord")};
				for my $rec (@results) {
					my ($notetype, $note) = @$rec;
					next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
					$text .= "\\raisebox{-0.5ex}{\\footnotemark}";	# lower footnotes so they're less ambiguous about being on its line
					$text .= '\\footnotetext{';
					$text .= '\textit{' if $notetype eq 'I'; # [Internal] 
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
		$text .= "\\end{longtable}\n" unless $lastgrpno eq ''; # if there were no forms, skip this
		$text .= "}\n\n";
		$e{records} = $text;
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
}

# print rootlets
# my $chapter_end_notes = $dbh->selectcol_arrayref(
# 	"SELECT xmlnote FROM notes WHERE spec='C' AND id='$fasc.$chap' AND notetype = 'F' ORDER BY ord");
# if (@$chapter_end_notes) {
# 	print "\\begin{center} * * * \\end{center}\n\n";
# }
# for my $note (@{$chapter_end_notes}) {
# 	print xml2tex(decode_utf8($note)) . "\n\n";
# }

my $tt = Template->new() || die "$Template::ERROR\n";
$tt->process("tt/chapter.tt", {
	fascicle => $fasc,
	chapter  => $chap,
	date     => $date,
	title    => $title,
	flowchartids => $flowchartids,
	chapter_notes => $chapter_notes,
	etyma    => \@etyma,
	internal_notes => $INTERNAL_NOTES,
	
}, "tex/$vol-$fasc-$chap.tex", binmode => ':utf8' ) || die $tt->error(), "\n";


$dbh->disconnect;
print STDERR "done!\n";


sub _tag2info {
	my ($t, $s) = @_;
	my $a_ref = $tag2info{$t};
	return "\\textit{[ERROR! Dead etyma ref #$t!]}" unless $a_ref;
	my ($printseq, $pform, $pgloss, $volume) = @{$a_ref};
	if ($printseq) { # if the root is in chapter 9, then put the print ref
		$t = "($printseq)";
		$t = "$volume $t" if $volume;
	} else {
		my ($hptb_page) =
			$dbh->selectrow_array(qq#SELECT mainpage FROM etyma, hptb WHERE etyma.hptbid = hptb.hptbid AND etyma.tag = $t#);
		if ($hptb_page) {
			$t = "(H:$hptb_page)";
		} else {
			$t = $ETYMA_TAGS ? "\\textit{\\tiny[#$t]}" : ''; # don't escape the # symbol here, it will be taken care of by escape_tex
		}
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
