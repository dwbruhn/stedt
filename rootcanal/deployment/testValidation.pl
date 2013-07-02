
sub validateContribution {
  my $fh = shift;
  my @messages;
  my %results;
  my $lines;
  my $show_stopper = 0;
  while ( <$fh> ) {
    chomp;
    $lines++;
    # check header
    if ($lines == 0) {
      $header = split "\t";
    }
    # check for missing values
    # check for "excrescences"
    # check well-formedness of gloss
    # check reflex
    # check POS if present
  }
  push(@messages, $lines . ' lines read, including header');
  $results{'status'}   = $show_stopper ? "Sorry, your file doesn't meet standards." : "File content OK!";
  $results{'messages'} = \@messages;
  seek($fh,0,0);
  return %results;
}

sub validateMetadata {
  my (%metadata) = @_;
  my @messages;
  my %results;
  my $lines;
  my $show_stopper = 0;
  foreach my $key (keys %metadata) {
    #check metadata elements
    print STDERR "$key:  $metadata{$key}\n";
    #$show_stopper = 1;
    $lines++;
  }
  push(@messages, $lines . ' parameters seen');
  $results{'status'}   = $show_stopper ? "Sorry, metadata insufficient." : "Metadata OK!";
  $results{'messages'} = \@messages;
  return %results;
}

my $file = shift @ARGV;
open(my $fh, "<:encoding(UTF-8)",$file) || die "no file given!\n";
 
my %results = validateContribution($fh);
print 'x' x 80;
print "\nchecking $file\n";
print 'x' x 80;
print "\nstatus: " . $results{'status'} . "\n";
foreach my $r (@{$results{'messages'}}) {
  print "$r\n";
}
