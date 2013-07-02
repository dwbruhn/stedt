
sub validateContribution {
  my $fh = shift;
  my @messages;
  my %results;
  my $lines;
  my $show_stopper = 0;
  while ( <$fh> ) {
    $lines++;
    #check each line
  }
  push(@messages, $lines . ' lines read');
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
my $fh = open $file || die "no file given!\n";
 
my %results = validateContribution($fn);
print 'x' x 80;
print "\nstatus: " . $results{'status'} . "\n";
foreach my $r (@{$results{'messages'}}) {
  print "$r\n";
}
