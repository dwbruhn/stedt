#!/usr/bin/perl
# extract all footnotes from all tex files in directory provided as argument (WITH TRAILING SLASH)

use strict;
use utf8;

binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");
binmode(STDERR, ":utf8");

# get list of tex files in directory that start with digit
opendir(DIR, $ARGV[0]) or die "Can't opendir directory provided: $!";
my @file_list = grep(/^\d.*?\.tex$/, readdir(DIR));
closedir(DIR);
@file_list = sort @file_list; # ASCII sort, works well enough to make things not too jumbled

foreach my $filename (@file_list) {
	
	my $depth = 0;	# keeps track of how deep we are inside a footnote
	my $cur_file;	# string to hold file contents
	my $cur_index = 0; # keeps track of current character being scanned
	my $fn_count = 0; # fn counter
	
	open(TEXFILE, $ARGV[0].$filename) or die "Could not open $filename. $!";
	binmode(TEXFILE, ":utf8");
	
	# load file contents into string
	while (<TEXFILE>) {
		$cur_file .= $_;
	}
	close(TEXFILE);
	
	print "\\section*{$filename}";
	
	$cur_file =~ s/\n/ /g; # replace all newlines with spaces
	my @chars = split("", $cur_file);	# split the file into an array
	
	# loop through each character in the array
	while ($cur_index < scalar @chars) {
		my $ch = $chars[$cur_index];	# store the character in $ch for convenience
	
		if ($depth) { # if we're inside a footnote, just print the character and keep going (no footnotes inside footnotes)
			print $ch;
			# adjust depth depending on whether we've entered another block or come out of one
			if ($ch eq '}') {
				$depth--;
				print "\n\n\n\n" if !$depth;	# if depth is now zero, we've exited a footnote, so print newlines to keep things cleaner
			}
			elsif ($ch eq '{') {
				$depth++;
			}
			
			$cur_index++;
			next; # jump to next character (shouldn't be footnotes inside footnotes)
		}
		
		if ($ch eq '\\' ) {
		# if we're outside a footnote and the character is a backslash, see if it starts a footnote command: \footnote{
			my @test_array = @chars[$cur_index..($cur_index+9)]; # get the substring
			my $test_string = join('', @test_array);
			if ($test_string eq '\\footnote{') { # it's a footnote command
				$fn_count++;
				print "\\textbf{$fn_count:} {";
				$depth = 1; # we've entered a footnote
				$cur_index += 10; # jump ahead because we already printed the whole footnote command
				next; # go to the first character inside the footnote
			}
		}
		
		# otherwise, it wasn't a footnote command, so just keep going
		$cur_index++;
	
	}
}