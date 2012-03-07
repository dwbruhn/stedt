#!/usr/bin/perl

use strict;
use Data::Dumper;
use utf8;
use DBI;
use SyllabificationStation;
use Encode qw/decode/;
use STEDTUtil;

binmode(STDOUT, 'utf8');

my $syls = SyllabificationStation->new();

binmode(STDOUT, 'utf8');

# get the juncture patterns (e.g. "ngkr" -> "ng-kr")
open(DAT, "juncpats.xls") || die("Could not open file!");
my %pats;
while (<DAT>) {
  chomp;
  $_= decode('utf8', $_);
  my ($f,$pat) = split("\t");
  my $sourcestr = $pat;
  $sourcestr =~ s/\-//g;
  $pats{$sourcestr} = $pat;
}

my @patarray = keys %pats;

# get the segment inventory, to get the list of vowels and diacritics
open(DAT, "chars.xls") || die("Could not open file!");
my %types;
while (<DAT>) {
  chomp;
  $_= decode('utf8', $_);
  my ($f,$seg,$type,$fuzzy) = split("\t");
  $types{$type} .= $seg;
}

my $vowels = '[' . $types{'v'} . ']';

sub breakJuncture {
  my ($str) = @_;
  return $str if $str =~ /[-◦ |]/; # don't mess with it if it already has delimiters
  foreach my $juncture (@patarray) {
    next unless $str =~ /$juncture/; # don't even both unless the string contains a target
    my $replacePat = $pats{$juncture};
    return $str if ($str =~ s/($vowels)$juncture($vowels)/\1$replacePat\2/);
  }
  return $str;
}

while (<>) {
  chomp;
  my ($rn,$reflex,$gloss,$gfn,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid) = split("\t");
  $gloss = from_utf8_to_xml_entities($gloss);
  $reflex = decode('utf8', $reflex);
  my $reflex = breakJuncture($reflex);
  #print '>>> ',$reflex,' ',$reflex2,"\n" if ($reflex ne $reflex2);
  $syls->split_form($reflex);
  #print Dumper($syls);
  my $s = 0;
  foreach (@{$syls->{syls}}) {
    print join("\t",($rn,$s,$_,$reflex,$gloss,$gfn,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid)) . "\n";
    $s++;
  }
  #my $xml = $syls->get_xml_mark_cog($etymon);
  #print "$rn\t$reflex\n";
}

sub format_protoform {
  my $string = shift;
  $string = decode('utf8', $string);
  # reverse order of tone letters (i.e.an initial cap) in reconstructions
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
