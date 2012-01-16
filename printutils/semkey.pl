#!/usr/bin/perl

# semcat.pl
# by JB Lowe 2011.12.12
#
# see USAGE, below.
#
#  Script to renew semkey assignments in Lexicon/Etyma tables
#  
#  1. Initialize: set initial conditions. NB: does NOT clear out existing semkeys!

use strict;
use utf8;
use Encode;
use Unicode::Normalize;
use STEDTUtil;

my ($table) = @ARGV;

unless ($table) {
	print <<USAGE;
Usage: $0 <lexicon|etyma>
USAGE
	exit;
}

my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");

my %stats;
my %glosswords; 
my %glosswordsWithNoKey;
my %glossesWithManySemkeys;
my %glossesWithNoSemkeys;
my %semkeys;
my %longGloss;

my $debug;

sub incrementStats {
  my ($stat) = @_;
  $stats{$stat}++;
}

sub updateLexiconSemkey {
  my ($dbh,$table,$semkey,$rn) = @_;
  $rn = $rn + 0; # make rn have correct type for mysql
  my $column = $table eq 'lexicon' ? 'rn' : 'tag'; 
  my $command = "UPDATE $table SET semkey = ? WHERE $column = ? AND $column != ''";
  my $sth = $dbh->prepare($command);
  $sth->execute($semkey, $rn);
}

sub checkWord {
  my ($word) = @_;
  return $glosswords{$word};
}

sub incrementUsedGlosswords {
  my ($word) = @_;
  $glosswords{$word}[1]++;
}

sub tokenizeGloss {
  my ($gloss) = @_;
  $gloss =~ tr/a-z/A-Z/; # make uppercase
  return split /\W+/,$gloss;
}

# TRUNCATE TABLE semkeys ;

#  2. Make a hash of glosswords and their semkeys
#  allow for a word to have more than one semkey: NOT DONE YET.

for (@{$dbh->selectall_arrayref("SELECT word,semkey FROM glosswords")}) {
  my ($word,$semkey) = map {decode_utf8($_)} @$_;
  next if $semkey eq 'x/';
  next if $semkey eq '/';
  incrementStats('number of words in glosswords');
  $glosswords{$word} = [$semkey,0];
  $semkeys{$semkey}++;
  $debug && printf "glosswords: %40s %40s\n",$word,$semkey;
}

#  3. Read, sequentially, each Lexicon record. (NB: allow, eventually, for a range of rns to be specified, for AddSource purposes)

my $command = $table eq 'lexicon' ? "SELECT gloss,gfn,rn,semcat FROM lexicon" : "SELECT protogloss,tag,tag,semkey FROM etyma";

for (@{$dbh->selectall_arrayref($command)}) {
  my ($gloss,$gfn,$rn,$semkey) = map {decode_utf8($_)} @$_;
  $debug && printf "lexicon: %30s ***%s***\n",$rn,$gloss;
  incrementStats('number of lexicon records processed');
  #  4. Check for the whole gloss in the word-semkey hash. if found, skip to step 7.
  #  5. Tokenize the gloss. Make an empty hash for semkey values for this gloss
  #  6. For each word in gloss:
  $gloss =~ tr/a-z/A-Z/;
  my $semkey = checkWord($gloss);
  my %tempSemkeys;
  if ($semkey) {
    $tempSemkeys{$semkey->[0]}++;
    incrementUsedGlosswords($gloss);
    $debug && printf "\tfull gloss found: %30s %10s\n",$gloss,$rn;
    incrementStats('number of full glosses found as glosswords');
    incrementStats("records composed of  1 found gloss");
  }
  else {
    my $numWords = 0;
    foreach my $word (tokenizeGloss($gloss)) {
      $numWords++;
      $debug && printf "\ttoken: %40s ",$word;
      incrementStats('number of words in all glosses');
      # look for it in word-semkey hash
      my $semkey = checkWord($word);
      # if found, add semkey to gloss hash
      # if not found, make a note, for final report
      if ($semkey) {
	$tempSemkeys{$semkey->[0]}++;
	incrementUsedGlosswords($word);
	$debug && printf "\tfound: %30s %20s\n",$word,$semkey->[0];
	incrementStats('number of gloss words which matched a glossword');
      }
      else {
	# log this word as a glossword with no semkey
	$glosswordsWithNoKey{$word}++;
	$debug && printf "\tnot found: %30s\n",$word;
	incrementStats('number of gloss words which did NOT match a glossword');
      }
    }
    my $distrib = "records w glosses composed of " . sprintf("%2d",$numWords) . ' word(s)';
    incrementStats($distrib);
    ($numWords > 20) && ($longGloss{$gloss} = $rn);
  }
# 7. Add a record to sem_hash table for this rn, for each semkey value
  my $distrib = "records having " . sprintf("%2d",scalar keys %tempSemkeys) . ' semkey(s) assigned';
  (scalar keys %tempSemkeys > 10) && ($glossesWithManySemkeys{$gloss} = $rn);
  incrementStats($distrib);
  if (scalar keys %tempSemkeys > 0) {
    incrementStats('number of records assigned a semkey');
    foreach my $tempsemkey (keys %tempSemkeys) {
      updateLexiconSemkey($dbh,$table,$tempsemkey,$rn);
      $debug && print "\tassigning ",$tempsemkey," to ",$rn,"\n";
      incrementStats('number of semkeys assigned in total');
    }
  }
  else {
    # no semkeys assigned! (nb: already counted in stats)
  }
 
}
#  8. Print a final report.
foreach my $stat (sort keys %stats) {
  printf "%-60s    %d\n", $stat, $stats{$stat};
}

print "\n\nUsed Glosswords\n\n";
foreach my $glossword (sort keys %glosswords) {
  ($glosswords{$glossword}->[1] > 0) && printf "%-40s  %-30s  %d\n", $glossword, $glosswords{$glossword}->[0],$glosswords{$glossword}->[1];
}
print "\n\nUnused Glosswords\n\n";
foreach my $glossword (sort keys %glosswords) {
  ($glosswords{$glossword}->[1] == 0) && printf "%-40s  %-30s  %d\n", $glossword, $glosswords{$glossword}->[0],$glosswords{$glossword}->[1];
}

print "\n\nWords (ASCII alphanumeric) in Glosses not found in Glosswords\n\n";
foreach my $word (sort keys %glosswordsWithNoKey) {
  ($word =~ /^[a-zA-Z0-9]+$/) && printf "%-40s    %d\n", $word, $glosswordsWithNoKey{$word};
}

print "\n\nWords with Special Characters in Glosses not found in Glosswords\n\n";
foreach my $word (sort keys %glosswordsWithNoKey) {
  ($word !~ /[a-zA-Z0-9]/) && printf "%-40s    %d\n", $word, $glosswordsWithNoKey{$word};
}

print "\n\Records with Lots of Semkeys\n\n";
foreach my $gloss (sort keys %glossesWithManySemkeys) {
  printf "%-40s    %d\n", $gloss, $glossesWithManySemkeys{$gloss};
}

print "\n\Records with No Semkeys\n\n";
foreach my $gloss (sort keys %glossesWithNoSemkeys) {
  printf "%-40s    %d\n", $gloss, $glossesWithNoSemkeys{$gloss};
}

$dbh->disconnect;
print "done!\n";

#print STDERR "generating vfc :: $vol.$fasc.$chap...\n";
#my $title = $dbh->selectrow_array(qq#SELECT chaptertitle FROM `chapters` WHERE `chapter` = '$vol.$fasc.$chap'#);
