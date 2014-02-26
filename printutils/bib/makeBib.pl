
while (<>) {
s/#/\\#/g;
s/[^\\]&/\&/g;
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
my @names = split(/[\s\.]/, $author);
$publisher = '' unless $publisher;
$publisher =~ s/^ +//g;

$author =~ s/, and\b/ and/g;

my $type = 'book';
my $publisher = '';
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
#print "citation = {$citation},\n";}

if ($author =~ /,/) {
  # do nothing
}
else {
  # author's name assumed to be chinese
  #small-capped non-Western author; still overgeneralizes (e.g., to "anonymous," "unknown")
  $author =~ s/^(.*?) (.*)$/{\\textsc{\1} \2}/;
}
print "author = {$author},\n";

#print "author   = {{$author}},\n";
print "year     = {$year},\n";
if ($imprint ne "") { print "imprint  = {$imprint},\n"; }
if ($address ne "") { print "address  = {$address},\n"; }
if ($publisher ne "") { print "publisher  = {$publisher},\n"; }
if ($journal ne "") { print "journal  = {},\n"; }
if ($imprint eq "") { print "imprint  = {},\n"; }
if ($address eq "") { print "address  = {},\n"; }
if ($publisher eq "") { print "publisher  = {},\n"; }
if ($journal eq "") { print "journal  = {},\n"; }
print "title    = {{$title}}\n";
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