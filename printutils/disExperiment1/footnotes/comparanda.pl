#!/usr/bin/perl
# extract all comparanda notes from all tex files in directory provided as argument

use strict;
use utf8;

binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");
binmode(STDERR, ":utf8");

# get list of tex files in directory (command-line argument) that start with digit
opendir(DIR, $ARGV[0]) or die "Can't opendir directory provided: $!";
my @file_list = grep(/^\d.*?\.tex$/, readdir(DIR));
closedir(DIR);
@file_list = sort @file_list; # ASCII sort, works well enough to make things not too jumbled

foreach my $filename (@file_list) {
	
	my $cur_file;	# string to hold file contents
	
	open(TEXFILE, "$ARGV[0]/$filename") or die "Could not open $filename. $!";
	binmode(TEXFILE, ":utf8");
	
	# load file contents into string
	while (<TEXFILE>) {
		$cur_file .= $_;
	}
	close(TEXFILE);
	
	# include etyma heading with comparanda
	my @matches = $cur_file =~ /(\\section.*?)\n.*?(\\comparandum.*?)(\\needspace{5\\baselineskip}|$)/gs;
	
	if (scalar @matches) {
		print "\n\\section*{$filename}\n@matches";
	}
}
