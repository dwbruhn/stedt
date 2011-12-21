#!/usr/bin/perl

use strict;
use utf8;
use DBI;
use CGI qw/:standard *table/;
use SyllabificationStation;
use Encode qw/decode/;
use CGI::Carp qw(fatalsToBrowser); #remove this later
use STEDTUtil;

binmode(STDOUT, 'utf8');

if (param('tag')) {
  makeheader();
  # make "dummy" volume, fascicle, and chapter to wrap this etyma display, so XSLt works right
  print "<volume>\n<num>Tag Display</num>\n<title></title>\n";
  print "<fascicle>\n<num>D R A F T</num>\n<title></title>\n";
  print "<chapter><chapternum></chapternum><chaptertitle></chaptertitle>\n" . byTag(param('tag')) ;
  print "</chapter>\n</fascicle>\n</volume>\n";
}

elsif (param('semkey')) {
  makeheader();
  byKey(param('semkey'));

}

else {
  print 
    header,
      start_html({-encoding=>'UTF-8',-title=>'STEDT Database: Electronic Dessimination of Etymologies'}),
	start_table({border=>'1', cellpadding=>'10'}),Tr,td{width=>'40'},
	  img({src=>'http://stedt.berkeley.edu/images/STB32x32.gif',align=>'LEFT'}),  
	    td,h3('STEDT Database Online'),       
	      b('Electronic dissemination of Etymologies'),
		td,font({-size=>'-2'}, 'v0.1 24 Mar 2005',br,'Lowe, Mortensen, Yu'),
		  Tr,td({colspan=>'3'},
			start_form({ -action => 'etymology.pl'}),
			"tag? ",textfield('tag'),
			submit{name=>'Make set'},
			end_form),  
			  end_table, 
			    hr,"\n";
  
  print end_html;
}

sub makeheader {  
  print "Content-type: text/xml\n\n";
  
  print <<EndXML;
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet href="fascicle.xsl" type="text/xsl"?>
EndXML
}

sub byKey {
  my ($key) = @_;

  my $dbh = STEDTUtil::connectdb();
  my $sql;
  my $sth;

  my ($volume,$fascicle,$inchapter) = split('\.',$key);

  my ($voltitle) = $dbh->selectrow_array("SELECT chaptertitle FROM chapters WHERE v = $volume");
  print "\n<volume>\n<num>$volume</num>\n<title>$voltitle</title>\n";

  my $where = " v = $volume ";
  $where .= " AND f = $fascicle " if ($fascicle);
  #$where .= " AND c = $inchapter  " if ($inchapter);
  $sql = "SELECT chapter, chaptertitle, v, f, c FROM chapters WHERE $where ORDER BY v,f,c,s1,s2,s3";
  $sth = $dbh->prepare($sql);
  $sth->execute();
  
  my ($chapter, $chaptertitle, $v, $f, $c);
  $sth->bind_columns(undef, \$chapter, \$chaptertitle, \$v, \$f, \$c);

  my $currf = $fascicle+0;
  #my $currc = $inchapter+0;
  my $chapters = "";
  my $startf = "" ;
  my $n = 0;
  while ($sth->fetch()) {
    #print "$chapter $chaptertitle $v $f $c currf = $currf \n";
    next if ($f == 0);
    if ($c == 0) {
      # cache this fascicle info
      print ">>> start: " . $chapter . "\n";
      $chaptertitle = from_utf8_to_xml_entities($chaptertitle);
      $startf = "\n<fascicle><num>$chapter</num><title>" . $chaptertitle . "</title>\n" ;
      my $etyma;
      #my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma WHERE chapter = '$chapter' AND sequence > 0 ORDER BY sequence");
      my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma WHERE chapter = '$chapter' ORDER BY sequence");
      foreach my $tag (@$tags) {
	#print "tag  ". $tag->[0] . "\n";
	$etyma .= byTag($tag->[0]) ;
      }	
      $startf .= "<chapter><chapternum>$chapter</chapternum><chaptertitle>$chaptertitle</chaptertitle>$etyma</chapter>\n" if $etyma;
    }
    elsif ($c == $inchapter+0 || $inchapter+0 == 0) {
      $chaptertitle = from_utf8_to_xml_entities($chaptertitle);
      # get the etyma for this chapter or subchapter
      my $etyma;
      #my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma WHERE chapter = '$chapter' AND sequence > 0 ORDER BY sequence");
      my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma WHERE chapter = '$chapter' ORDER BY sequence");
      foreach my $tag (@$tags) {
	$etyma .= byTag($tag->[0]) ;
      }
      $chapters .= "<chapter><chapternum>$chapter</chapternum><chaptertitle>$chaptertitle</chaptertitle>$etyma</chapter>\n";
    }
    if ($currf != $f) {
      print $startf . $chapters . "</fascicle>\n" if ($startf);
      $chapters = "";
    }
    $currf = $f;
    #$currc = $c;
  }
  # output the last one
  print $startf . $chapters . "\n</fascicle>\n" if ($startf);
  print "</volume>\n";
    
}

sub byTag {
  my ($etymon) = @_;
  
  my $dbh = STEDTUtil::connectdb();
  my $sql;
  my $sth;
  
  # Query for record from Etyma database
  
  $sql = "SELECT protoform, protogloss, chapters.chapter, chapters.chaptertitle, sequence FROM etyma, chapters WHERE etyma.chapter=chapters.chapter AND tag=?";
  #print STDERR "$sql\n";
  $sth = $dbh->prepare($sql);
  $sth->execute($etymon);
  
  my ($protoform, $protogloss, $chapter, $chaptertitle, $sequence);
  $sth->bind_columns(undef, \$protoform, \$protogloss, \$chapter,
		     \$chaptertitle, \$sequence); $sth->fetch() or warn "Can't get etyma info\n";
  
  $protoform = format_protoform($protoform);
  $protogloss = from_utf8_to_xml_entities($protogloss);
  
  #print STDERR "$protoform\t$protogloss\t$chapter\t$chaptertitle\t$sequence\n";
  
  my $etymology = <<EndXML;
  <etymology>
    <seqno>$sequence</seqno>
    <paf>$protoform</paf>
    <pgloss>$protogloss</pgloss>
    <stedtnum>$etymon</stedtnum>
EndXML
  
  # Query for records from Notes database for etymon
  
  $sql = "SELECT xmlnote FROM notes WHERE id=?";
  $sth = $dbh->prepare($sql);
  $sth->execute($etymon);
  
  my $note;
  $sth->bind_columns(undef, \$note);
  
  while ($sth->fetch()) {
    $note = decode('utf-8', $note);
    $etymology .= "<desc>\n<note>$note</note>\n</desc>\n" if $note;
    
  }
  
  # Monster query from Lexicon, LanguageNames, LanguageGroups, and Lexicon-Etyma Hash
  
  $sql = <<EndOfSQL;
SELECT DISTINCT languagegroups.grpno, grp, language, lexicon.rn, 
       analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid 
  FROM lexicon, languagenames, languagegroups, lx_et_hash
  WHERE (lx_et_hash.tag = $etymon
    AND lx_et_hash.rn=lexicon.rn
    AND languagenames.lgid=lexicon.lgid
    AND languagenames.grpid=languagegroups.grpid)
  ORDER BY languagegroups.grpno, language
EndOfSQL
  # $sql = <<EndOfSQL;
  # SELECT DISTINCT languagegroups.grpno, grp, language, lexicon.rn, 
  #        analysis, reflex, gloss, languagenames.srcabbr, lexicon.srcid, 
  #        notes.xmlnote
  #   FROM lexicon, languagenames, languagegroups, lx_et_hash
  #   LEFT JOIN notes ON notes.rn=lexicon.rn
  #   WHERE (lx_et_hash.tag=?
  #     AND lx_et_hash.rn=lexicon.rn
  #     AND languagenames.lgid=lexicon.lgid
  #     AND languagenames.grpid=languagegroups.grpid)
  #   ORDER BY languagegroups.grpno, language
  # EndOfSQL
  
  $sth = $dbh->prepare($sql);
  $sth->execute();
  
  my ($grpno, $grp, $language, $rn, $analysis, 
      $reflex, $gloss, $srcabbr, $srcid, $rnote);
  $sth->bind_columns( undef, \$grpno, \$grp, \$language, 
		      \$rn, \$analysis, \$reflex, \$gloss, 
		      \$srcabbr, \$srcid);
  
  my ($prev_grpno, $prev_lang);
  my $first = 1;
  
  my $syls = SyllabificationStation->new();
  
  my $nonempty = 0;
  
  while ($sth->fetch()) {
    $nonempty = 1;
    $gloss = from_utf8_to_xml_entities($gloss);
    $reflex = decode('utf8', $reflex);
    $analysis = decode('utf8', $analysis);
    # start of hack: handle non-xml encoded chars: double them, then undouble them.
    $reflex =~ s/[><\&]/\1\1/g;
    $syls->fit_word_to_analysis($analysis, $reflex);
    my $xml = $syls->get_xml_mark_cog($etymon);
    # end of hack:
    grep { $xml =~ s/($_)$_/\1/g } ('<','>','&');
    
    if ($first) {
      $etymology .=  <<EndXML;
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
      $first = 0;
    } elsif (not $grpno eq $prev_grpno) {
      $etymology .=  <<EndXML;
    </subgroup>
    <subgroup>
      <sgnum>$grpno</sgnum>
      <sgname>$grp</sgname>
EndXML
    }
    $etymology .=  <<EndXML;
      <reflex>
    	<lgname>$language</lgname>
	<rn>$rn</rn>
	<analysis>$analysis</analysis>
	<form>$xml</form>
	<gloss>$gloss</gloss>
	<srcabbr>$srcabbr</srcabbr>
	<srcid>$srcid</srcid>
EndXML
    if ($rnote) {
      $etymology .=  "	<rnote>$rnote</rnote>\n";
    }
    $etymology .=  "      </reflex>\n";
    ($prev_grpno, $prev_lang) = ($grpno, $language);
  }
  $etymology .=  "    </subgroup>\n" if ($nonempty);
  $etymology .=  "  </etymology>\n";

$dbh->disconnect();

return $etymology

} 

sub format_protoform {
  my $string = shift;
  $string = decode('utf8', $string);
  $string =~ s{(\A|\s)(\w)}{$1*$2}gx;
  return $string;
}

sub from_utf8_to_xml_entities {
  my $string = shift;
  my @subst = (
	       ['&', '&amp;'],
	       ['<', '&lt;'],
	       ['>', '&gt;'],
	       ["'", '&apos;'],
	       ['"', '&quot;']);
  for my $pair (@subst) {
    my ($symbol, $entity) = @$pair;
    $string =~ s($symbol)($entity)g;
  }
    return $string;
}