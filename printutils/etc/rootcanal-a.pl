#!/usr/bin/perl

# rootcanal-a.pl
# by Dominic Yu
# 2007.06.07
# ----------
# This generates a XeLaTeX document extracting
# ZMYYC and TBL (and others) from the database.

use strict;
use utf8;
use Encode;
#use SyllabificationStation;

use DBI;
use CGI::Carp qw/fatalsToBrowser/;

my %seenQueries;

binmode(STDOUT, ":utf8");
my %groupno2name = (
	0=>'Sino-Tibetan',
	1=>'Kamarupan',
	2=>'Himalayish',
	3=>'Tangut-Qiang',
	4=>'Jingpho-Nung-Luish',
	5=>'Tujia',
	6=>'Lolo-Burmese',
	7=>'Karenic',
	8=>'Bai',
	9=>'Sinitic',
	X=>'Other TB'
);

my @roots;
@roots = split /\n/, <<'EOF';
# PLB Tone *1		
ALL (WHICH/WHO) %ALL[[:>:]]	999	ka	qha	xhá		-I
BASKET (carrying/storage)	437		qha-jɔ̀ʔ	xhá-phù
CATCH	557	da
CLASSIFIER (general)	951,949,955,953, 954, 952, 948		mà	má
CLOTH %CLOTH[[:>:]]	388		pha	shà-phá		prob. < Tai
COME	737	lá	là	lá	la
EASY/PLEASANT	878		ša	shá	sa
FERN/BRACKEN	----		dà	dá-pjaq		LQ nt'u
GOOD / PERMISSIBLE	860	ʔná	na
HANDSPAN %HANDSPAN/SPAN	960		thu		thwa
HOOF	175				khwa
HOT/SUNSHINE 	883, 835	tshá	cha	tshá
HUNDRED	939	há	ha	já	ʔəra
I / ME %I[[:>:]]/ME[[:>:]]	969	ŋá	ŋâ	ŋà	ŋa
LISTEN/ASK	532	ná	na	ná-hà
MAIZE %MAIZE/CORN	193	ʃá-ǹ	ša-ma
NOSE	240	ʔná-khw	nā-qhɔ̂	ná-mɛ́	hna	-T
ONLY	----				sa	Jg. šà
PATCH	653				ʔəpha	[see *p-/w-]
PLACE %PLACES?[[:>:]]	TBL 64		kà	gá, à-gá
PLOUGH	414, 595	ma
RICE (in the field)	186, 390	zá	cà	djá-dè
RIGHTSIDE	54	ʒá	làʔ-ya		lak-ya
RAIN	8	á-ǹ-há			rwa
SEEK/LOOK FOR	678		ca	sjhá	hra
SICK	776	ná	nà		na
SPARROW	148		jà-mə̂	djá-tsəq	ca
STICK (n.)	429		à-tà	dá-khɔ̀
SWIDDEN	28		hɛ	já	ya
TEA %TEA[[:>:]]	TBL 454	là-phìq	là-phàʔ		ləphak	-T
THROW AWAY	558		bà	bá 'go away, dispel'
TONGUE	245	ʔlá	ha-tɛ̄	mɛ̀-lá	hlya
TRAP (falling log)	TBL 638, 639		va-tɛ̂	ja-dm̀
WEAR/CLOTHE/DRESS	TBL 1548, 1211					Lisu gwa
WINNOW	642		ha	zá ~ já
W. TRAY %WINNOWING/TRAY	TBL 630	ʔva-ma 	ha-ma 
WOUND/INJURY	TBL 124			má		WT rma


# PLB Tone *2		
ARROW	428			kaq-mjà	hmrâ
BAMBOO	183		vâ		wâ
BEE	TBL 367		pɛ̂	bjà	pyâ
BETWEEN/INTERVAL	----		(ɔ̀-)kā	khà	khrâ, krâ
BITTER	889	khà	qhâ	xhà	khâ
BORROW/LEND	692	à-ǹ	ŋā	ŋà	hŋâ
BUCKWHEAT	190, 191	ɣà	g̈â
CATTLE	109, 111	á-ǹ	nû		nwâ
CHEEK/FACE	236	bà-kjɛ́	pâ	bà-ba	pâ
CIVET CAT %CIVET	----		pā-vı̂	pjhà-ǜ
COCK'S COMB %COCK''S COMB/COCKSCOMB	TBL 297		g̈âʔ-nā-jɨ	nà-bɛ
DOOR/MOUTH	353, 242				tam-khâ 'door'
EAR %EAR[[:>:]]	241	ʔnà	nā	nà	nâ
EARTH/GROUND	17, 31		mı̀-châ	mı́-tshà
EAT/FEED	533	dzà	câ 	dzà	câ	simplex
EAT/FEED(caus.)	608		cā			causative
EDGE/TIP	61		ɔ̀-jâ	mɛ̀-dzà
FEVER	----			pjhà	phyâ
FISH	151	à-ǹ	ŋâ	ŋà	ŋâ
FIVE	915	ŋà	ŋâ	ŋà	ŋâ
FONTANELLE	----		ú-g̈â
FOREHEAD	233		nā-qā-pɨ	ná-xhɔ́		-T
FROG	150		pā-tɛ́-nɛ̂ʔ	xhà-phà	phâ
GO %GO[[:>:]]	738				swâ
HEAR	532	gà	kâ	gà	krâ
INTERROGATIVE PRT %INTERROGATIVE	----		lâ	là	lâ
JEWSHARP	507		á-thâ
JOKE/TEASE	----		bâ	bá		-T
LIVESTOCK/DOM.ANIMAL %LIVESTOCK/DOMESTIC/ANIMAL	TBL 253, 303		cê-cà	djè-zà
MALE (ANIMAL)	----		vàʔ-pā	zàq-phà		'boar'
MANY	819		mâ	mjà	myâ	-G
MEAT/FLESH/ANIMAL	399	xà	šā	sjhà	sâ
MULE	112, 114				lâ
NEARBY/VICINITY	818		ɔ̀-pâ(-nê)		ʔə-pâ
NEG. IMPERATIVE	1004	thà	tâ	thà		-I
OLD (FIELD)	----		hɛ-šā	já-shà
PALM/SOLE	----			làq-zà	phəwâ
POOR/MISERABLE	909		hā	sjhà	hrâ
PUT DOWN/KEEP	660		tā	thà	thâ
REST/PAUSE/STOP/STAY	581		nâ	nà	nâ
SALT	398	tshà-bùq		phàŋ ɣò tshà	châ
SNOW	9	và	vâ
SON / CHILD %SON[[:>:]]/CHILD	339, 295	zà	yâ		sâ
STRENGTH/WIN/CLF.PEOPLE %STRENGTH/WIN[[:>:]]	513	ɣà	ɔ̀-g̈â		ʔâ
TEACH	621	ʔmà	mā		hmâ
THIN	852, 812		pâ	bà, bjà	pâ
TOOTH	244		-šū		swâ
TIME / WHEN	62	thà-sı̀	thâ (Prt)
TIGER	124	là-pàq	lâ	xhà-là	kyâ < klâ
TROUSERS	379	ʔlà	hā
YEAR (Belab)	63			...qhɔ̀ʔ...bâ	xòq kəq à-bà


# PLB Tone *3		
BEGIN	793				ca'
BOX	TBL 527, 529		ta-qō		ta
BRIGHT/CLEAR/SHINE	833, 835	ba	ba	bja	pa'
CHANGE/EXCHANGE	773, 695		pa	phá		-T
ELEPHANT	123	xa	hɔ			YL ya-ma
FALL (meteorological)	577		qa	ga
FATHER	319	phà	ɔ̀-pa		ʔəbha'	-T
FEMININE SUFFIX	----		-ma	-ma	ʔəma' 'mother'
FRYING PAN	TBL 546		ha-chɨ	my-za
HELP	699	ga	ga	ga dja dja
MOON/MONTH	3, 74	xa-ba	ha-pa	ba-la	la'
OBTAIN/GET	675	ɣa	g̈a	za ~ ja	ra'
SOUL	524	há-zà	ɔ̀-ha	sàq-lá	hla'
SOW/PLANT (v.)	598	kha	qha	kha


# PLB Tone not clear or variable		
BAMBOO	183	ma
CHEW	536	ga		bɛ̂
CICADA	----		tá-ve	dà-jù		-T
COTTON	199	sá-là	šá-lâ	shà-là		Lisu sa³la⁵
DANCE/SING	683		qa-mɨ̀	gá njɛ njɛ	ka'
DANCE/SING	684		qā-qhêʔ
DUMB/MUTE	302		qā		ʔa'
ELDER BROTHER	333		à-ka			Mand. gē
EMBRACE/HUG	TBL 1505, 1762, 1575		bɛ̂	bjá tjùq
GOAT/ANTELOPE	117		hâ-tɔ́-pɛ̂ʔ	jà	 	Liau h'ya⁵
GOITER	----					WT lba-ba
GRAIN OF RICE %GRAIN	----	dzà-khá	cà-qha	khá
INTENTION (Prt)	----		šā	shá u
KNIFE	409	a-thà	á-tà		thâ
LONG FOR / WANT	674	gà	gâ (Pv)
NEGATIVE	1003	mà	mâ		ma'	-T
OTHER SIDE/SHADE	----		ɔ̀-bà-phɔ̂	bá-lá	ʔəpa' 'outside part'	-T
QUIET	----		tàʔ-ı́ chɛ̂	dà tı́ tjhú i		-T
YAWN	TBL 1243		há mɨ̀		ha'	-T
EOF

my @lgs;
@lgs = split /\n/, <<'EOF';
Achang - TBL #28
Achang - ZMYYC #41
Bola - TBL #32
Langsu - TBL #31
Langsu (Maru) - ZMYYC #43
Leqi - TBL #33
Xiandao - TBL #29
Zaiwa - TBL #30
Zaiwa (Atsi) - ZMYYC #42
Ahi - CK-YiQ,CK-CS
Ahi Mile - ZMYYC #25
Akha - PL
Bisu - PB-Bisu,PB-MB
Burmese (Written) - AJ
Dafang - ZMYYC #22
Hani Caiyuan (Biyue) - ZMYYC #30
Hani Dazhai - ZMYYC #31
Hani Luqun - TBL #41
Hani Mojiang - TBL #42
Hani Shuikui (Haoni) - ZMYYC #32
Jinuo - TBL #44
Jinuo - ZMYYC #34
Lahu - JAM
Lalo (SB) - SB
Lalo - CK-YiQ,CK-CS
Lipho - CK-YiQ,CK-CS
Lisu - TBL #40
Lisu - ZMYYC #27
Mojiang - ZMYYC #26
Mpi - SD-MPD
Nanhua - TBL #37
Nanhua - ZMYYC #24
Nanjian - ZMYYC #23
Nasu - CK-YiQ,CK-CS
Naxi Lijiang - TBL #45
Naxi Lijiang - ZMYYC #28
Naxi Yongning (Moso) - ZMYYC #29
Neisu - CK-YiQ,CK-CS
Nesu - CK-YiQ,CK-CS
Nosu - CK-YiQ,CK-CS
Phunoi - DB-PLolo,DB-Phunoi 
Sangkong - LYS-Sangkon
Sani - TBL #39
Sani [Nyi] - CK-YiQ,CK-CS
Weishan - TBL #36
Wuding - TBL #38
Xide - TBL #35
Xide - ZMYYC #21
EOF

#Lalo (SB) - SB-LaloGr,SB-Lalo
#Akha - PL-AED,PL-AETD
#Burmese (Written) - AJ-BED

#print 'Content-type:application/x-latex';
#print "Content-Type:application/x-download";
print "Content-Type:text/plain; charset=UTF-8";

#print "\r\n";
#print "Content-Disposition:attachment;filename=blah.tex";
# Content-Disposition not part of HTTP 1.1, but widely implemented
print "\r\n\r\n";


my $dbh = connectdb();
#my $syls = SyllabificationStation->new();

print <<'EOF';
%!TEX TS-program = xelatex
%!TEX encoding = UTF-8 Unicode
\documentclass[10pt]{article}

\usepackage{fontspec}
\usepackage{xunicode} % for real tildes with \textasciitilde
\setromanfont[ItalicFont=Charis SIL Italic]{Charis SIL}
% unresolved bug in xetex

% \setmonofont[Scale=0.8]{AppleGothic Regular}
\newcommand{\TC}[1]{{\fontspec{Apple LiSung Light}#1}}
\newcommand{\IPA}[1]{{\fontspec{Charis SIL}#1}}
\newcommand{\STEDTU}[1]{{\fontspec{STEDTU Roman}#1}}

\usepackage{fullpage}
\usepackage{parskip}

\usepackage{natbib}
%\usepackage[sectionbib]{natbib}
\bibpunct[:]{(}{)}{;}{a}{}{,}
%\renewcommand{\bibsection}{\section{References}}

\usepackage{multicol}
\usepackage{longtable}
\usepackage{array,ragged2e} % for raggedright inside tables

\setlength\LTleft{0pt} 
\setlength\LTright\fill

\title{Root canal \#1}
\author{STEDT}
\date{2007.06.07}

\begin{document}
\bibliographystyle{linquiry2}

\maketitle

\raggedright

EOF

my $newpagedone = 0;
foreach (@roots) {
	next if /^$/;
	if (/^#(.*)/) {
		print "\\newpage\n"; $newpagedone = 1;
		print "$1\n\n";
		next;
	}
	my ($gloss, $refstr, $f_lalo, $f_lahu, $f_akha, $f_wb, $remarks) = split /\t/;
	
	my $altgloss = ($gloss =~ /%(.*)/) ? $1 : $gloss; # relevant for non-ZMYYC/TBL lgs
	$altgloss =~ s/ ?\(.*//g;
	$gloss =~ s/%.*//g; # fix gloss so it's printable
	
	my $srcabbr = '';
	if ($refstr =~ /^\d/) {
		$srcabbr = 'ZMYYC';
	} elsif ($refstr =~ /^TBL +(.*)/) {
		$srcabbr = 'TBL';
		$refstr = $1;
	}
	print "\\newpage\n" unless $newpagedone;
# 	unless ($srcabbr) {
# 		print $_ . "\n\n";
# 		print("no ZMYYC/TBL reference - skipping\n\n");
# 		$newpagedone = 0;
# 		next;
# 	}
	
	$newpagedone = 1;
	for my $ref (split /, */, $refstr) {
		print "\\newpage\n" unless $newpagedone;
		
		$ref = sprintf("%04i",$ref) if $srcabbr eq 'TBL';
		print "$gloss - $srcabbr $ref - $remarks\n\n";
		print "\\begin{longtable}{rlp{4in}c}\n";
		my $n = 0;
		my $maingloss = ''; # one main gloss for each ref
		foreach (@lgs) {
			$n++;
			my ($lg, $idstr) = split / - /;
			my $bySrcId = $srcabbr && ($idstr =~ /^ZMYYC/ or $idstr =~ /^TBL/);

			# do search
			my $sql;
			if ($bySrcId) {
				next if $idstr !~ /$srcabbr/; # TBL and ZMYYC are mutually exclusive
				$idstr =~ /#(\d+)/;
				my $id = $1;
				$sql = <<EndOfSQL;
SELECT DISTINCT lexicon.rn, analysis, reflex, gloss, notes.rn
  FROM lexicon, languagenames
  	LEFT JOIN notes ON notes.rn=lexicon.rn
  WHERE (languagenames.srcabbr = '$srcabbr'
    AND lexicon.srcid = '$ref.$id'
    AND languagenames.lgid=lexicon.lgid)
EndOfSQL
#, lx_et_hash
#    AND lx_et_hash.rn=lexicon.rn
			} else {
				my $srcabbrSearch = ($idstr =~ /^JAM$|^SB$|^PL$|^AJ$/)
					? '' #"languagenames.srcabbr LIKE 'JAM-%' AND (languagenames.language = 'Lahu' OR languagenames.language = 'Lahu (Black)')"
					: join(' OR ', map {"languagenames.srcabbr='$_'"} split /,/,$idstr);
				my $glossSearch =
					join(' OR ', map {"lexicon.gloss RLIKE '[[:<:]]$_'"} split / ?\/ ?/,$altgloss);
				#my $lgSearch = $lg;
				$sql = <<EndOfSQL;
SELECT DISTINCT lexicon.rn, analysis, reflex, gloss, notes.rn
  FROM lexicon, languagenames
  	LEFT JOIN notes ON notes.rn=lexicon.rn
  WHERE (($srcabbrSearch)
    AND  languagenames.language = '$lg'
    AND  ($glossSearch)
    AND languagenames.lgid=lexicon.lgid)
  ORDER BY reflex
EndOfSQL
				$seenQueries{$sql}++;
			}
			my $specialform;
			$specialform = $f_lahu if $idstr eq 'JAM';
			$specialform = $f_lalo if $idstr eq 'SB';
			$specialform = $f_akha if $idstr eq 'PL';
			$specialform = $f_wb   if $idstr eq 'AJ';
			my $recs;
			if ($idstr =~ /^JAM$|^SB$|^PL$|^AJ$/) {
				if ($specialform) {
					$recs = [['','',$specialform,$maingloss]];
				} else {
					$recs = [];
				}
			} else {
				$recs = $dbh->selectall_arrayref($sql);
				for my $rec (@$recs) {
					$_ = decode_utf8($_) foreach @$rec; # do it here so we don't have to later
				}
			}
			
			# print the forms
			#print "{\\footnotesize\n";
			next unless @$recs;
			next if (@$recs > 10) && ($seenQueries{$sql} > 1);
			print $n . ". & $lg & ";
			
			my @notes;
			my $lastform;
			for my $rec (@$recs) {
				my ($rn,$an,$form,$gloss,$notern) = @$rec;
				if (!defined($lastform) || $form ne $lastform) {
					if (defined($lastform)) # if it's not the first time.
					{
						print " & ";
						# take notes out of queue and print them
						print_notes(@notes);
						@notes = ();
						print "\\\\&& ";
					}
					$an = "($an)" if $an;
					print escape_tex($form) . " $an ";
					print "‘" . escape_tex($gloss) . "’" if $gloss ne $maingloss;
					if ($maingloss eq '') { $maingloss = $gloss; }

					$lastform = $form;
				}
				push @notes, $notern if $notern;
			}
			print " & ";
			# footnotes, if any
			print_notes(@notes);
				
			print "\\\\\n";
			}
		print "\\end{longtable}\n";
		$newpagedone = 0;
	}

	$newpagedone = 0;
}

print <<'EOF';
\end{document}
EOF

$dbh->disconnect;

sub print_notes {
	my @notes = @_;
	if (@notes) {
		my $notern = join(' OR ', map {"rn=$_"} @notes);
		for my $rec (@{$dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
				. "WHERE $notern ORDER BY ord")}) {
			my ($notetype, $note) = @$rec;
			print '\footnote{';
			print '[Internal] \textit{' if $notetype eq 'I';
			print '[Orig/Source] ' if $notetype eq 'O';
			print escape_tex(xml2tex(decode_utf8($note)));
			print '}' if $notetype eq 'I';
			print "}\n";
		}
	}
}

sub escape_tex {
	my $s = shift;
	$s =~ s/#/\\#/g;
	$s =~ s/&/\\&/g;
	$s =~ s/~/\\textasciitilde\\ /g;
	$s =~ s/([ⓁⓋⓒⒸⓈ˯˰⪤↮↭])/\\STEDTU{\1}/g;
	# this marks special symbols not really in unicode as STEDTU font
	# VL, VD, checked, tone C, stopped tone, low open, low stopped, allofam symbols
	$s =~ s/◦/·/g; # STEDT delimiter, not in Charis SIL, can be del'd
	$s =~ s/\|//g; # STEDT overriding delimiter, can be safely ignored
	return $s;
}

sub xml2tex {
	local $_ = $_[0];
	s|^<par>||;
	s|</par>$||;
	s|</par><par>|\n\n|g;
	s|<sub>(.*?)</sub>|\$_\\mathrm{$1}\$|g;
	s|<emph>(.*?)</emph>|\\textit{$1}|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|\\textbf{*$1}|g;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|#$1$2|g;
	s|<hanform>(.*?)</hanform>|\\TC{$1}|g;
	s|<latinform>(.*?)</latinform>|$1|g;
	s/&amp;/&/g;
	s/&lt;/</g;
	s/&gt;/>/g;
	s/&apos;/'/g;
	s/&quot;/"/g;
	return $_;
}

# special functions to combine similar records
sub eq_reflexes {
	my ($a, $b) = @_;
	$a =~ tr/+ .,;~◦⪤-=\|//d; # remove spaces and delimiters
	$b =~ tr/+ .,;~◦⪤-=\|//d;
	$a =~ s/ː/:/g; # normalize vowel length to ASCII colon
	$b =~ s/ː/:/g;
	return $a eq $b;
}

sub eq_glosses {
	my ($a, $b) = @_;
	$a =~ tr/ ;\/,//d;
	$b =~ tr/ ;\/,//d;
#	printf "%vd", $^V if $c;
#	print "Now doing $a vs $b\n\n" if $c;
	$a =~ s/¶/%%%%%/g;	# some stupid glitch prevents utf8 from being used for split. it's even worse with  (apple logo, PUA)
	foreach (split /%%%%%/, $a) {
#		print "$_ vs $b = " . ($_ eq $b) . "\n\n" if $c;
		return 1 if $_ eq $b;
	}
	return 0;
}

sub src_concat {
	my @abbrs = split /;/, $_[0];
	my @ids   = split /;/, $_[1];
	my $result = $abbrs[0];
	$result .= ":$ids[0]" if $ids[0];
	
	my $lastabbr = $abbrs[0];
	for my $i (1..$#abbrs) {
		if ($abbrs[$i] eq $lastabbr) {
			$result .= ",$ids[$i]" if $ids[$i];
		} else {
			$result .= "; $abbrs[$i]";
			$result .= ":$ids[$i]" if $ids[$i];
			$lastabbr = $abbrs[$i];
		}
	}
	return escape_tex($result); # escape the pound symbols in the srcid
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
