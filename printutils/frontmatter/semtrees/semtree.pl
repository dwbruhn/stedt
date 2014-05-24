#!/usr/bin/perl
# semtree.pl
# by Daniel Bruhn
# 2014.05.23
#
# grabs chapter table from db and generates tikz-qtree trees for semantic hierarchy
# creates file semtree.tex for inclusion in semtree_wrapper.tex

use lib '../..';

use strict;
use utf8;
use Encode;
use FascicleXetexUtil;
use STEDTUtil;
use Template;

my $dbh = STEDTUtil::connectdb();
binmode(STDERR, ":utf8");

my $query = "SELECT semkey, chaptertitle, v, f, c, s1, s2, s3
	FROM chapters
	WHERE semkey NOT IN ('999', 'x.x', '950.1')
	ORDER BY v,f,c,s1,s2,s3";

my @trees = ("\\Tree\n") x 10; # set up tikz-qtree code for each semtree volume

# keep track of levels in tree
my $prev_level = -1;
my $cur_level;
# keep track of volumes
my $prev_vol = 1;

my ($semkey,$chaptertitle,$v,$f,$c,$s1,$s2,$s3);

for (@{$dbh->selectall_arrayref($query)}) {
	($semkey,$chaptertitle,$v,$f,$c,$s1,$s2,$s3) = map {decode_utf8($_)} @$_;

	# skip lower levels for now
#	next if ($s3);
	
	 # if we've moved to the next volume, need to close the final nodes in the previous volume
	 # and update previous level variable to start over
	if ($v != $prev_vol) {
		for (my $i = $prev_level; $i >= 0; $i--) {
			$trees[$v-2] .= "\t" x $i . "]\n"; # close the previous node
		}
		$prev_level = -1;
	}
	
	# find the current tree level
	if ($s3) {
		$cur_level = 5;
	} elsif ($s2) {
		$cur_level = 4;
	} elsif ($s1) {
		$cur_level = 3;
	} elsif ($c) {
		$cur_level = 2;
	} elsif ($f) {
		$cur_level = 1;
	} else {
		$cur_level = 0;
	}

	# if we're on the same level or have backed out, need to close the previous node(s)
	for (my $i = $prev_level; $i >= $cur_level; $i--) {
		$trees[$v-1] .= "\t" x $i . "]\n"; # close the previous node
	}
	
	$trees[$v-1] .= "\t" x $cur_level; # insert appropriate # of tabs for current node
	my $node_text = "$semkey " . escape_tex($chaptertitle); # concatenate semkey and chapter title (escape tex-specific chars)
	$node_text =~ s/(.{20}[^\s]*)(\s+|\/)/$1$2\\\\/g; # add line break sequence about every 20 chars or so
#	print "$node_text\n";
	$trees[$v-1] .= "[.{$node_text}\n"; # tree code for the current node
		
	$prev_level = $cur_level;
	$prev_vol = $v;
}

#close last node(s)
for (my $i = $prev_level; $i >= 0; $i--) {
	$trees[$v-1] .= "\t" x $i . "]\n"; # close the previous node
}

my $tt = Template->new() || die "$Template::ERROR\n";
$tt->process("semtree.tt", {
	trees   => \@trees,
}, "semtree.tex", binmode => ':utf8' ) || die $tt->error(), "\n";
