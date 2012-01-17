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

while (<>) {
  chomp;
  my ($rn,$reflex,$gloss,$gfn,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid) = split("\t");
  $gloss = from_utf8_to_xml_entities($gloss);
  $reflex = decode('utf8', $reflex);
  $syls->split_form($reflex);
  #print Dumper($syls);
  my $s = 0;
  foreach (@{$syls->{syls}}) {
    $s++;
    print join("\t",($rn,$s,$_,$reflex,$gloss,$gfn,$lg,$grp,$grpno,$srcabbr,$srcid,$semkey,$lgid)) . "\n";
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
