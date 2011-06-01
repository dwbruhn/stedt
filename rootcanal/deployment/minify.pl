#! /usr/bin/perl
# minify.pl
# by Dominic Yu
# read in a javascript file and output the minified version in the right dir

use JavaScript::Packer;
undef $/; # 'slurp' mode to read in a whole file

my $in = shift @ARGV;
my $out = $in;
$out =~ s|^.*?/js/|$ENV{HOME}/public_html/js/|;
# print "$in -> $out\n";
# exit;
open F, "<$in" or die $!;
open G, "<$out" or die $!;
my $minified = JavaScript::Packer::minify(\<F>, {remove_copyright=>1});
my $dst_txt = <G>;
if ($dst_txt eq $minified) {
	# print STDERR "skipped  $out\n";
	exit;
}
close G or die $!;
open G, ">$out" or die "$! - $out";
print G $minified;
close F or die $!;
close G or die $!;
print STDERR "minified $out\n";
