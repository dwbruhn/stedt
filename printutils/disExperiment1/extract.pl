#!/usr/bin/perl

# extract.pl
# completely refactored by JB Lowe
# 2014.07.18
#
# based loosely on an original by Dominic Yu
# 2011.02.03
#
# see USAGE, below.
#
# Briefly:
#
# This script now treats vols. 1 and 2 specially: the semantic sectioning and sequence, arrived
# at by hard labor, are retained as is.
#
# for vols 3-10, nodes in the semantic tree are "lumped" at the chapter level, i.e.
# *  all nodes below V.F.C are combined and
# *  the etyma are resequenced in order by protogloss.
#
# To accomplish this, the program first makes a hash of all the VFCs that will be handled (and
# this then is the number of tex files that will be generated.
#
# (of course for vols. 1 and 2, a "V.F.C" may in fact be a "V.F or a "V.F.C.S.S.S", got it?)
#
# Then it goes through each VFC and makes a combined list of etyma, which it then sorts
# by protogloss before passing through the template.
#
# other than that, the script does pretty much the same thing it did before; note that
# most of the "Internal Only" stuff -- hidden etyma, internal notes, has either been torn out
# or reconfigured. 
#
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

my %STATS;
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

for (@{$dbh->selectall_arrayref("SELECT etyma.tag, etyma.chapter, etyma.protoform, etyma.protogloss, languagegroups.plg
	FROM etyma LEFT JOIN languagegroups USING (grpid)")}) {
  my ($tag,@info) = map {decode_utf8($_)} @$_;
  $info[1] = '*' . $info[1];
  $info[1] =~ s/⪤} +/⪤} */g;
  if (!($info[0] =~ /^[12]/)) {  # truncate semkey at three levels (VFC) if not volume 1 or 2
    $info[0] =~ s/^([^.]+\.[^.]+\.[^.]+)(?:\..+)$/$1/; # fancy regex to strip off semkey levels below VFC
  }
  $tag2info{$tag} = \@info;
}
$FascicleXetexUtil::tag2info = \&_tag2info;

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

my %vfcs;
my $counter = 0;

my ($texfilename,$visualvfckey,$semkeyx,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info);
my ($ivol,$ifasc,$ichap,$is1,$is2,$is3);

print STDERR "q: $query\n";

for (@{$dbh->selectall_arrayref($query)}) {
  ($semkeyx,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info) = map {decode_utf8($_)} @$_;

  my $texfilename;
  my $vfckey;
  my $visualvfckey;

  if ($v == 1 || $v == 2) {
    $texfilename = $semkeyx;
    $texfilename =~ s/\./\-/g;
    $visualvfckey = $semkeyx;
    $vfckey = ($v + 100) . "." . ($f + 100) . "." . ($c + 100)  . "." . ($s1 + 100) . "." . ($s2 + 100)  . "." . ($s3 + 100) ;
  }
  else {
    $texfilename = "$v-$f-$c";
    $visualvfckey = "$v.$f.$c";
    $vfckey = ($v + 100) . "." . ($f + 100) . "." . ($c + 100);
  }

  $texfilename =~ tr/A-Z/a-z/;
  $texfilename =~ s/\-x//g;
  $texfilename .= '-0' unless $texfilename =~ /\-/; 

  print STDERR ">> file: $texfilename, semkey: $semkeyx, sortkey for semkey: '$vfckey'\n";

  $vfcs{$vfckey}{$counter++} = [ $texfilename,$visualvfckey,$semkeyx,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info ];
}


foreach my $vfc (sort keys %vfcs) {

  my $title;
  my $flowchartids;
  my @allflowchartids;
  my @all_chapter_notes;
  my @etyma;
  my $semkey;
  
  my $sectioncount = 0;

  my %sectionvalues = %{ $vfcs{$vfc} } ;
  my @first = sort keys %sectionvalues;
  ($texfilename,$visualvfckey,$semkeyx,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info) = @{ $sectionvalues{@first[0]} };
  $texfilename = $vfcs{$vfc}{texfilename};
  print STDERR "\n>>> VFC: $visualvfckey (sortkey = $vfc)\n";

  @etyma =() ;      # array of infos to be passed on to the template
  @all_chapter_notes = ();
  @allflowchartids = ();

  # lumping everything beyond the vfc level (jblowe 7/15/2014)
  foreach my $counter (sort keys %sectionvalues) {

    ($texfilename,$visualvfckey,$semkeyx,$chaptertitle,$v,$f,$c,$s1,$s2,$s3,@info) = @{ $sectionvalues{$counter} };

    $sectioncount++;
    print STDERR "  == $sectioncount ::: ($counter) $semkeyx: $chaptertitle\n";

    # map what is in the db to variables we can use in this script.
    $ivol  = $v == 0 ? 'x' : $v;
    $ifasc = $f == 0 ? 'x' : $f;
    $ichap = $c == 0 ? 'x' : $c;
    $is1   = $s1 == 0 ? 'x' : $s1;
    $is2   = $s2 == 0 ? 'x' : $s2;
    $is3   = $s3 == 0 ? 'x' : $s3;

    $semkey = "$ivol.$ifasc.$ichap.$is1.$is2.$is3";
    $semkey    =~ s/\.x//g;
    $semkey .= '.0' unless $semkey =~ /\./; 
    if ($sectioncount == 1) {
      $title = $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `semkey` = '$semkey'#);
      $title = escape_tex($title);
    }
    $flowchartids = $dbh->selectcol_arrayref("SELECT noteid FROM notes WHERE spec='C' AND id='$semkey' AND notetype='G'");
    #print STDERR "generating VFC $texfilename :: '$title'...\n";

    if ($ifasc == $fasc && $ichap == $chap) {
      $mastertitle = escape_tex($chaptertitle);
      $masterVFC = $semkey;
      print STDERR "  ++ $masterVFC $mastertitle\n";
    }

    # build etyma hash
    print STDERR "  >> Building etyma data for $semkey\n";
    my $nextseq = 1;

    my $chapter_notes = [
			 map {xml2tex(decode_utf8($_))} @{$dbh->selectcol_arrayref(
			 "SELECT xmlnote FROM notes WHERE spec='C' AND id='$semkey' AND (notetype = 'T' OR notetype = 'N') ORDER BY ord")}
			];

    # change first word of chapter note to dropcaps + smallcaps
    $chapter_notes = [map { s/^(\w)(\w+) /\\lettrine{\1}{\2} /; $_ } @$chapter_notes];

    #print STDERR "  chapter notes: ", @$chapter_notes;

    my $extra_where = ($INTERNAL_NOTES ? "" : "AND e.sequence >= 1"); # extra condition to exclude unsequenced etyma when this is a non-draft version
    my $special = " e.chapter = '$semkey'";
    #$special = " e.chapter LIKE '$semkey%'" if ((scalar split('\.',$semkey) > 2) && ($semkey =~ /^[^12]./));
    my $etyma_in_chapter = $dbh->selectall_arrayref(
						    qq#SELECT e.tag, e.sequence, e.protoform, e.protogloss, languagegroups.plg
		FROM `etyma` AS `e` LEFT JOIN languagegroups ON e.grpid=languagegroups.grpid
		WHERE e.uid=8 AND status != 'DELETE' AND $special $extra_where
		ORDER BY e.sequence#);

    print STDERR '  >> Found ' . (scalar @$etyma_in_chapter) . " etyma in this chapter, ";
    print STDERR (scalar @$chapter_notes) . " chapter note(s) found, ";
    print STDERR (scalar @$flowchartids) . " flowcharts(s) found.\n";

    @all_chapter_notes = (@all_chapter_notes, @$chapter_notes);
    # @all_chapter_notes = map {my $outer = $_; map {($outer, $_)} @all_chapter_notes} @chapter_notes;
    @allflowchartids = (@allflowchartids, @$flowchartids);
    print STDERR "  Accumulated so far: " . scalar @all_chapter_notes . ' flowcharts: ' . scalar @allflowchartids, "\n";

    # skip entire chapter if it has no etyma and there is nothing else to print, unless it is a volume or fascicle beginning.
    # if it is a V or F, semkey will have the form DIGIT(S).DIGIT(S)
    if ((0 == scalar @$etyma_in_chapter) && (0 == scalar @$chapter_notes) && (0 == @$flowchartids)) {
      print STDERR "  >> skipping $semkey: no data.\n";
      next;
    }
    else {
      print STDERR "  >> continuing with $semkey.\n";
    }
    my $etyma_index = 0; # index for accessing next etymon in array (to check sequence number and identify PAFs)
    foreach (@$etyma_in_chapter) {

      $STATS{1}{'total'}{etyma}++;
      $STATS{2}{$vol}{etyma}++;
      $STATS{3}{$visualvfckey}{etyma}++;

      # check if current etymon is a PAF (then it should be included even if it has no records)
      my $seq_cur = $etyma_in_chapter->[$etyma_index][1]; # get sequence number of current etymon
      my $seq_next = (scalar @$etyma_in_chapter == $etyma_index+1) ? 0 : $etyma_in_chapter->[$etyma_index+1][1]; # get sequence number of following etymon, but don't overrun array
      my $isPAF = (int($seq_cur) == $seq_cur && int($seq_cur) == int($seq_next)); # etymon is a PAF is decimal portion of seq is zero and integer portion matches following seq
	
      my %e;			# hash of infos to be added to @etyma

      # heading stuff
      @e{qw/tag seq protoform protogloss plg/}
	= map {escape_tex(decode_utf8($_))} @$_;

      print STDERR "    #$e{tag}: '$e{protogloss}' ($e{seq}) ";
      # mess with sequence number if its an "autosequence" number...
      #print STDERR "before nextseq $nextseq :: " . int($e{seq}) . "\n";
      $nextseq = int($e{seq}) if (int($e{seq}) < 1000);
      $e{seq} = $nextseq if (int($e{seq}) >= 1000);
      $nextseq++;
      #print STDERR "after nextseq $nextseq :: " . int($e{seq}) . "\n";

      #index gloss parts
      #if $e{protogloss} =~ /\W/
      my @tempgloss = split('/', $e{protogloss});
      foreach my $glosspart (@tempgloss) {
	$glosspart =~ s/^\s+|\s+$//g;
	$glosspart .= " \\index\{$glosspart\}";
      }

      $e{protogloss} = join(' / ', @tempgloss);

      # $e{plg} = '' unless $e{plg} eq 'IA';
      # $e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";

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
      if (@$recs) {		# skip if no records
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
	#my $group_space = '';
	for my $rec (@$recs) {
	  my ($grpno,$grp,$lg,$rn,$an,$form,$gloss,$gfn,$srcabbr,$srcid,$notern)
	    = @$rec;
	  next unless $lg;	# skip duplicate forms (see above)

	  $STATS{1}{'total'}{reflexes}++;
	  $STATS{2}{$vol}{reflexes}++;
	  $STATS{3}{$visualvfckey}{reflexes}++;
	  $STATS{4}{$semkey . ' ' . $e{tag}}{reflexes}++;
			
	  if ($grpno ne $lastgrpno) {
	    $text .= '[1ex]' unless $lastgrpno eq ''; # add space above this row
	    my ($tmp_grpno, $grpname);
	    while (@{$e{mesoroots}} && $e{mesoroots}[0]{grpno} lt $grpno
		   || @{$e{subgroupnotes}} && $e{subgroupnotes}[0]{grpno} lt $grpno) {
	      if (@{$e{mesoroots}} && $e{mesoroots}[0]{grpno} lt $grpno) { # if there are mesoroots or mesoroots + subgroup note(s)
		$tmp_grpno = $e{mesoroots}[0]{grpno};
		$grpname   = $e{mesoroots}[0]{grp};
	      } else {		# otherwise just subgroup note(s)
		$tmp_grpno = $e{subgroupnotes}[0]{grpno};
		$grpname   = $e{subgroupnotes}[0]{grp};
	      }
	      my ($meso, $note) = get_meso_notes($e{mesoroots}, $e{subgroupnotes}, $tmp_grpno);
	      $text .= "\\multicolumn{4}{>{\\hangindent=.8in}p{5.7in}}{$tmp_grpno. $grpname";
	      $text .= $meso;
	      $text .= '}&';
	      $text .= $note;
	      #$text .= "\\\\\n";
	      $text .= "\\\\*$group_space\n";
	    }
	    my ($meso, $note) = get_meso_notes($e{mesoroots}, $e{subgroupnotes}, $grpno);
	    $text .= "\\multicolumn{4}{>{\\hangindent=.8in}p{5.7in}}{\\textsc{$grpno. $grp}";
	    $text .= $meso;
	    $text .= '}&';
	    $text .= $note;
				#$text .= "\\\\\n";
	    $text .= "\\\\*$group_space\n"; # if the star doesn't work, use \\nopagebreak before the \n
	    $lastgrpno = $grpno;
	  }
			
			
	  $syls->fit_word_to_analysis($an, $form);
	  $form = $syls->get_brace_mark_cog($e{tag}) || $form;
	  $form =~ s/(\S)=(\S)/$1꞊$2/g; # short equals - must be done AFTER syllabification station			
	  $form =~ s/{/\\textbf{/g;
	  $form = '*' . $form if ($lg =~ /^\*/); # put * for proto-lgs
	  if ($lg eq 'Chinese (Hanzi)') { # deal with Chinese chars (need \TC or \SC)
	    if ($srcabbr eq 'YN-RGLD') {
	      $form = '\\SC{' . $form . '}'; # Nagano db uses simplified
	    } else {
	      $form = '\\TC{' . $form . '}'; # other sources (Baxter-Sagart, HPTB) use traditional
	    }
	  }
	  if ($lg eq $lastlg) {
	    $lg = '';		# don't repeat the lg name if same
	  } else {
	    $lastlg = $lg;
	  }
	  $lg = escape_tex($lg);
	  $lg = '{}' . $lg if $lg =~ /^\*/; # need curly braces to prevent \\* treated as a command!
	  $lg = '\\textit{' . $lg . '}';
	  $gfn =~ s/\.$//; # remove any trailing period from gfn to avoid double periods
	  my $gloss_string = ($gfn) ? "$gloss ($gfn.)" : $gloss; # concatenate with gfn if it's not empty
	  $text .= join(' &', $lg, escape_tex(      $form      ,1),
			escape_tex($gloss_string), src_concat("\\citealt{$srcabbr}", $srcid), ''); # extra slot for footnotes...
			
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
	      $text .= '[Source Note] ' if $notetype eq 'O';
	      $text .= xml2tex(decode_utf8($note));
	      $text .= '}' if $notetype eq 'I';
	      #$text .= "}\\\\\n";
	      $text .= "}";
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
	$text .= "}\n";
	#$text .= "\n";
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
	$STATS{1}{'total'}{comparanda}++;
	$STATS{2}{$vol}{comparanda}++;
	$STATS{3}{$visualvfckey}{comparanda}++;
	$STATS{4}{$semkey . ' ' . $e{tag}}{comparanda}++;
      }
      # saving the best for last ... include this etymon if it has some reflexes, or if it's a PAF, or if this is a draft (even if etymon has no reflexes)
      push @etyma, \%e if ((scalar(@$recs) > 0) || $isPAF || $INTERNAL_NOTES);
      $etyma_index++; # increment index to access next sequence number
    }
  }
  my $tt = Template->new() || die "$Template::ERROR\n";
  #next if 0 == scalar @etyma;

  if ((0 == scalar @etyma) && (0 == scalar@all_chapter_notes) && (0 == @allflowchartids)) {
    print STDERR "  >> not writing anything for $semkey: no data.\n";
  }
  else {
    
    # sort all etyma by protogloss, if not vol 1 or 2.
    if ($v != 1 && $v != 2) {
      my @sorted = sort { $a->{protogloss} cmp $b->{protogloss} } @etyma ;
      my $sequence = 0;
      my %pghash;
      for my $eee (@etyma) {
	my $seq_cur = $eee->{seq};
	if (int($seq_cur) == $seq_cur) {
	  $pghash{$eee->{protogloss}} .= $eee->{protogloss};
	  $sequence++;
	}
	else {
	  
	}
      }
      #grep { $_->{seq} = $sequence++; } @etyma ; # print "seq $sequence :: " . $_->{protogloss} . "\n";
    }
    
    # prettify sequence number
    grep { 
      $_->{seq} =~ s/\.0$//;
      # nb only works on single digits
      $_->{subseq} = $_->{seq} =~ /\.(\d)/ ? chr(96+$1) : $1;
      $_->{seq} =~ s/\.(\d)//; 
    } @etyma ;
    
    
    print STDERR "  Writing file $texfilename, semkey=$semkey, ($vol,$fasc,$chap) " . scalar @etyma . " etyma; " . 
      scalar @allflowchartids . " flowchart(s); " . scalar @all_chapter_notes . " ch note(s).\n";
    
    $tt->process("tt/chapter.tt", {
				   semkey   => $visualvfckey,
				   volume   => $ivol,
				   fascicle => $ifasc,
				   chapter  => $ichap,
				   date     => $date,
				   title    => $title,
				   author   => $author,
				   flowchartids => \@allflowchartids,
				   chapter_notes => \@all_chapter_notes,
				   etyma    => \@etyma,
				   internal_notes => $INTERNAL_NOTES,
				  }, "tex/${texfilename}.tex", binmode => ':utf8' ) || die $tt->error(), "\n";
    push @texfilenames,$texfilename;  
  }
  
  undef @allflowchartids;
  undef @allflowchartids;
  undef @etyma;
}

my $tt = Template->new() || die "$Template::ERROR\n";
$tt->process("tt/master.tt", {
			      semkey   => $masterVFC,
			      date     => $date,
			      xtitle    => $mastertitle,
			      author   => $author,
			      texfilenames => \@texfilenames,

			     }, "tex/${mastertexfilename}", binmode => ':utf8' ) || die $tt->error(), "\n";

open STATS,">tex/${mastertexfilename}.stats.csv";
print STATS "start\t" . scalar localtime . "\n";
foreach my $stat (sort keys %STATS) {
  next if $stat > 3;
  my %onestat = %{ $STATS{$stat} };
  foreach my $indv (sort keys %onestat) {
    print STATS $stat . "\t";
    print STATS $indv;
    for my $stype (qw(etyma reflexes comparanda)) {
      print STATS "\t" . ($onestat{$indv}{$stype}+0) ;
    }
    print STATS "\n";
  }
}

$dbh->disconnect;
print STDERR "done!\n";

sub _tag2info {
  my ($t, $s) = @_;
  my $a_ref = $tag2info{$t};
  return "\\textit{[ERROR! Dead etyma ref #$t!]}" unless $a_ref;
  my ($chapter, $pform, $pgloss, $plg) = @{$a_ref};
  $t = $ETYMA_TAGS ? "\\textit{\\tiny[#$t]}" : ''; # don't escape the # symbol here, it will be taken care of by escape_tex
  $pform =~ s/-/‑/g;		# non-breaking hyphens
  $pform =~ s/⪤ /⪤ */g;	# add a star for proto-allofams
  $pform =~ s/(\*\S+)/\\textbf{$1}/g; # bold the protoform but not the allofam sign or gloss
  if ($s) {				# alternative gloss, add it in
    $s = "$plg $pform $s";
  } else {
    $s = "$plg $pform $pgloss";	# put protogloss if no alt given
  }
  $s = " $s" if $t;	   # add a space between if there's a printseq

  return "\\textbf{$t}$s (§$chapter)"; # provide VFC of etymon after cross-reference
}

sub format_protoform {
  my $s = shift;
  for ($s) {
    s/⪤} +/⪤} */g;
    s/ OR +/ or */g;
    s/\\textasciitilde{} +/\\textasciitilde{} */g;
    s/ = +/ = */g;
    s/, +/, */g;	# add star to protoforms separated by commas (e.g. PKC verb-stem alternations)
    s/; +/; */g;	# add star to protoforms separated by semicolons (e.g. PKC)
    s/^/*/;		# star at beginning of field
    s/(\*[^\s,;]+)/\\textbf{$1}/g; # bold only the protoform, not allofam, "or", comma, or semicolon
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
    $meso_string = ": "; # omit redundant plg abbreviation; original line: $meso_string = ": $m[0]{plg} ";
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
