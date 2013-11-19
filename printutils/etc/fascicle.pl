#!/usr/bin/perl

# fascicle.pl
# by Dominic Yu
# 2007.05.25
# ----------
# This generates a XeLaTeX document creating the
# body parts fascicle.
# 
# curly braces will not always show up in the typeset version... i tried
# to work around this, but at least the reflexes suppress curly braces.
# luckily there aren't too many records that have {}'s

use strict;
use utf8;
use Encode;
use Unicode::Normalize;
use SyllabificationStation;
use FascicleXetexUtil;
use EtymaSets; # for group names
use STEDTUtil;

my $INTERNAL_NOTES = 0;
my $ETYMA_TAGS = 0;

binmode(STDOUT, ":utf8");

#print 'Content-type:application/x-latex';
#print "Content-Type:application/x-download";
#print "\r\n";
#print "Content-Disposition:attachment;filename=blah.tex";
# Content-Disposition not part of HTTP 1.1, but widely implemented

#print "Content-Type:text/plain; charset=UTF-8";
#print "\r\n\r\n";
# disabled because we prefer to run from command line, then FTP

my $dbh = STEDTUtil::connectdb();
my %groupno2name = EtymaSets::groupno2name($dbh);
my $syls = SyllabificationStation->new();

# build etyma hash
my %tag2info;  # this should only be used inside xml2tex, for looking up etyma refs
for (@{$dbh->selectall_arrayref("SELECT tag,chapter,printseq,protoform,protogloss FROM etyma")}) {
	my ($tag,$chapter,@info) = map {decode_utf8($_)} @$_;
	if ($chapter !~ /^9.\d$/) {
		$info[0] = ''; # make printseq empty if not in fascicle
	}
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

$ARGV[0] =~ s/[^\d,]//g;
my @sections_list = split /,/, $ARGV[0];
@sections_list = (1..9) unless $ARGV[0];

for my $section (@sections_list) { # actually chapters
	# print "\\newpage\n" unless $section == 1;
	open my $tmp_fh, ">:utf8", "fsrc/$section.tex" or die $!;
	select $tmp_fh; # set default for print
	print STDERR "generating chapter $section...\n";
	
	print '\chapter{'
		. $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `chapter` = '9.$section'#)
		. "}\n\n";
	my $etyma_in_section = $dbh->selectall_arrayref(
		qq#SELECT tag, printseq, protoform, protogloss, plg,
					notes, xrefs, allofams, possallo, hptbid
			FROM `etyma`
			WHERE `chapter` = '9.$section'
			ORDER BY `sequence`#);# AND tag=3487
	
	# print semantic flowchart
	for my $noteid (@{$dbh->selectcol_arrayref("SELECT noteid FROM notes WHERE "
			. "spec='C' AND id='9.$section' AND notetype='G'")}) {
		print qq#\\XeTeXpdffile "pdf/$noteid.pdf"  width \\textwidth\n\n#; # don't forget the space, for xetex to parse filename
	}
	print "\\vspace{1em}\n";
	
	# print chapter notes
	for my $note (@{$dbh->selectcol_arrayref(
		"SELECT xmlnote FROM notes WHERE spec='C' AND id='9.$section' AND notetype = 'T' ORDER BY ord")}) {
		print xml2tex(decode_utf8($note)) . "\n\n";
	}

	foreach (@$etyma_in_section) {
		# print heading
		my ($tag, $printseq, $protoform, $protogloss, $plg,
				$notes, $xrefs, $allofams, $possallo, $hptbid) = map {escape_tex(decode_utf8($_))} @$_;
		$plg = '' unless $plg eq 'IA'; # Jim wants to not show this, ever. 2007.08.07
		# $plg eq 'PTB' ? '' : "$plg";

		$protoform =~ s/⪤} +/⪤} */g;
		$protoform = '*' . $protoform;
		my $tmp_protoform = $protoform;
		$tmp_protoform =~ s/\\STEDTU{⪤}/⪤/g; # make hyperref stop complaining about "Token not allowed in a PDFDocEncoded string"
		
		# make protoform pretty
		$protoform =~ s/(\*\S+)/\\textbf{$1}/g; # bold only the protoform, not allofam or "or"
			# perhaps better to use [^ ] instead of \S...
		
		my $tmp_markright = "($printseq) $plg $protoform $protogloss";
		my $tmp_plaintext = "($printseq) $plg $tmp_protoform $protogloss";
		
		$protoform = prettify_protoform($protoform); # make vertical

		print "\\etymon";
		print "[\\texorpdfstring{$tmp_markright}{$tmp_plaintext}]\n{";
			print "($printseq)\\hspace{\\stretch{1}}";
			print "$plg $protoform";
			print "\\hspace{\\stretch{1}}\\textbf{$protogloss}";
			print " \\textit{\\tiny[\\#$tag]}" if $ETYMA_TAGS;
		print "}\n";
#		print "\\nopagebreak[4]\n\n";
		# other stuff from the etyma record
#		\\\\{}\n";
			# put in {} to prevent brackets being interpreted as argument to \\ (newline/vertical space)
# 		print "\\textit{[\\#$tag";
# 		print "; $notes" if $notes;
# 		print "; xrefs: $xrefs" if $xrefs;
# 		print "; \\STEDTU{⪤} $allofams" if $allofams;
# 		print "; \\STEDTU{↭} $possallo" if $possallo;
# 		print "]}\n\n";

		# print notes
		my $seen_hptb;
		for my $rec (@{$dbh->selectall_arrayref("SELECT notetype, xmlnote, noteid FROM notes "
				. "WHERE tag=$tag AND notetype != 'F' ORDER BY ord")}) {
			my ($notetype, $note, $noteid) = @$rec;
			next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
			$seen_hptb = 1 if $notetype eq 'H';

			print '[Internal] \textit{' if $notetype eq 'I';
			print '[Orig/Source] ' if $notetype eq 'O' && $INTERNAL_NOTES;
			my $s = xml2tex(decode_utf8($note));
			
			# special handling for one particular note:
			if ($noteid == 7275) {
				$s =~ s/7/\\hangindent=3ex 7/; # assume only one 7
				$s =~ s/(Inherited Germanic material)/\\hspace*{0.25in} \\begin{minipage}{6.75in}\r{\\small\r$1/;
				$s =~ s/(Borrowings from other)/\\vspace{1ex}\r\r$1/;
				$s =~ s/(\\textit{vodka})/$1\r}\r\\end{minipage}/;
			}
			print $s;
			print '}' if $notetype eq 'I';
			print "\n\n";
		}
		if ($hptbid && !$seen_hptb) {
			print "See \\textit{HPTB} ";
			my @refs = split /,/, $hptbid;
			my @strings;
			foreach (@refs) {
				my ($id, $altpages) = split /%/;
				my ($pform, $plg, $pages) =
					$dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=$id");
				$pform = decode_utf8($pform);
				if ($altpages) {
					$altpages =~ s/;/, /g;
					$pages = $altpages;
				}
				my $p = ($pages =~ /,/ ? "pp" : "p");
				push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "\\textbf{$pform}, $p.~$pages";
			}
			print escape_tex(join('; ', @strings), 1);
			print ".\n\n";
		}


		


		# do entries
		my $sql = <<EndOfSQL; # this order forces similar reflexes together, and helps group srcabbr's
SELECT DISTINCT languagegroups.ord, grp, language, lexicon.rn, 
       analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, notes.rn
  FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
  WHERE (lx_et_hash.tag = $tag
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

			$syls->fit_word_to_analysis($an, $form);
			$form = $syls->get_brace_mark_cog($tag) || $form;
			$form =~ s/(\S)=(\S)/$1$2/g; # short equals - must be done AFTER syllabification station
			$form =~ s/{/\\textbf{/g;
			$form = '*' . $form if ($lg =~ /^\*/); # put * for proto-lgs
			if ($lg eq $lastlg) {
				$lg = '';			# don't repeat the lg name if same
			} else {
				$lastlg = $lg;
			}
			$lg = '{}' . $lg if $lg =~ /^\*/; # need curly braces to prevent \\* treated as a command!
			print join(' &', $lg, escape_tex(      $form      ,1),
				$gloss, src_concat($srcabbr, $srcid), '');	# extra slot for footnotes...
			
			# footnotes, if any
			if ($notern) {
				$notern = join(' or ', map {"`rn`=$_"} split /,/, $notern);
				# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
				my @results = @{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
						. "WHERE $notern AND (`id`=$tag OR `id`='') ORDER BY ord")};
				for my $rec (@results) {
					my ($notetype, $note) = @$rec;
					next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
					print "\\raisebox{-0.5ex}{\\footnotemark}";	# lower footnotes so they're less ambiguous about being on its line
					print '\\footnotetext{';
					print '[Internal] \textit{' if $notetype eq 'I';
					print '[Orig/Source] ' if $notetype eq 'O';
					print xml2tex(decode_utf8($note));
					print '}' if $notetype eq 'I';
					print "}\n";
				}
			} elsif ($ETYMA_TAGS) {
				print "\\hspace*{1ex}";
			}
			if ($ETYMA_TAGS && $an && $an ne $tag && $an ne "$tag,$tag") { # for internal purposes, print out analysis 
				$an =~ s/\b$tag\b/\\textasciitilde/g;
				print "{\\tiny $an}";
			}
			
			print "\\\\\n";
		}
		print "\\end{longtable}\n" unless $lastgrpno eq ''; # if there were no forms, skip this
		print "}\n\n";
		}



		# Chinese comparanda
		my @comparanda = @{$dbh->selectcol_arrayref("SELECT xmlnote FROM notes WHERE tag=$tag AND notetype = 'F' ORDER BY ord")};
		my $comparand_um_a = "Chinese comparand" . (@comparanda == 1 ? 'um' : 'a');
		#print "{\\large \\textbf{$comparand_um_a}\\addcontentsline{toc}{subsection}{$comparand_um_a}}\\nopagebreak[4]\n\n" if @comparanda;
		print "\\comparandum[\\textit{$comparand_um_a}]{$comparand_um_a}\n\n" if @comparanda;
		for my $note (@comparanda) {
			$note = decode_utf8($note);
			$note =~ s/{/\\{/g; $note =~ s/}/\\}/g; # escape curly braces here.
			$note =~ s/(Karlgren|Li|Baxter): /\\hfill $1: /g;
			$note = xml2tex($note,1); # don't convert curly braces
			$note =~ s/^(\\TC{(.)} \\textbf{(.*?)},?)/$1 \\index{$3 $2}/mg;
				$note =~ s/(\\textbf\{zǎn\} ‘have in mouth; bite; sting’)/$1 \\index{zǎn 噆}/ if $section == 4;
				$note =~ s/(taboo word \\TC{(屄)})/$1 \\index{bī $2}/ if $section == 5;
				$note =~ s/(\\TC{(痒)} \\textbf{(yáng)})/$1 \\index{$3 $2}/ if $section == 8;
			$note =~ s/^(\[ZJH\])$/\\hfill $1/mg;
			$note =~ s/^(\[JAM\])$/\\hfill $1/mg;
			print $note, "\n\n";
		}
	}
	
	# print rootlets
	my $chapter_end_notes = $dbh->selectcol_arrayref(
		"SELECT xmlnote FROM notes WHERE spec='C' AND id='9.$section' AND notetype = 'F' ORDER BY ord");
	if (@$chapter_end_notes) {
		print "\\vspace{1ex}\n";
		print "\\begin{center} * * * \\end{center}\n\n";
	}
	for my $note (@{$chapter_end_notes}) {
		print xml2tex(decode_utf8($note)) . "\n\n";
	}
	
	print "\\cleartooddpage[\\thispagestyle{empty}]\n";
	select STDOUT; # restore it, just for good form
	close $tmp_fh or die $!;
}

$dbh->disconnect;
print STDERR "done!\n";

sub _tag2info {
	my ($t, $s) = @_;
	my $a_ref = $tag2info{$t};
	return "\\textit{[ERROR! Dead etyma ref #$t!]}" unless $a_ref;
	my ($printseq, $pform, $pgloss) = @{$a_ref};
	if ($printseq) { # if the root is in chapter 9, then put the print ref
		$t = "($printseq)";
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
