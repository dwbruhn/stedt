
while (<>) {
my ( $srcabbr    ,
 $citation   ,
 $author     ,
 $year       ,
 $imprint    ,
 $title      ,
 $status     ,
 $location   ,
 $notes      ,
 $dataformat ,
 $format     ,
 $haveit     ,
 $todo       ,
 $proofer    ,
 $inputter   ,
 $dbprep     ,
 $dbload     ,
 $dbcheck    ,
 $callnumber ,
 $scope      ,
 $refonly    ,
 $citechk    ,
 $pi         ,
 $totalnum   ,
 $infascicle ) = split "\t";

$year =~ s/\.//;
$imprint =~ s/^ +//g;
my ($address, $publisher) = split ':',$imprint;
$publisher = 'unknown' unless $publisher;
$publisher =~ s/^ +//g;

my $type = 'book';
my $publisher = 'unknown';
my $journal;
my $pages;
if ($imprint =~ /:\d/) {
  $type = 'article';
  $journal = $address;
  $pages = $publisher;
  $publisher = '';
  $address = '';
}

print '@' . $type . '{' . $srcabbr . ",\n";
#print "citation = {$citation},\n";
print "author   = {$author},\n";
print "year     = {$year},\n";
if ($imprint ne "") { print "imprint  = {$imprint},\n"; }
if ($address ne "") { print "address  = {$address},\n"; }
if ($publisher ne "") { print "publisher  = {$publisher},\n"; }
if ($journal ne "") { print "journal  = {$journal},\n"; }
print "title    = {$title}\n";
#print "status   = {$status},\n";
#print "location = {$location},\n";
#print "notes    = {$notes },\n";
#print "dataformat = $dataformat},\n";
#print "format   = {$format},\n";
#print "haveit   = {$haveit},\n";
#print "todo     = {$todo  },\n";
#print "proofer  = {$proofer},\n";
#print "inputter = {$inputter},\n";
#print "dbprep   = {$dbprep},\n";
#print "dbload   = {$dbload},\n";
#print "dbcheck  = {$dbcheck},\n";
#print "callnumber = {$callnumber },\n";
#print "scope    = {$scope},\n";
#print "refonly  = {$refonly    },\n";
#print "citechk  = {$citechk    },\n";
#print "pi       = {$pi    },\n";
#print "totalnum = {$totalnum   },\n";
#print "infascicle  infascicle },\n";
print "}\n\n";
}
