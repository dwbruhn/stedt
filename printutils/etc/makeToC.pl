#!/usr/bin/perl -w

use utf8;
use DBI;
use CGI;
use CGI qw/:standard *table/;

sub connectdb {
  my $host = 'localhost';
  my $db = 'stedt';
  my $db_user = 'root';
  my $db_password = '';

  my $dbh = DBI->connect("dbi:mysql:$db:$host", "$db_user",
                         "$db_password",
                         {RaiseError => 1,AutoCommit => 1})
    || die "Can't connect to the database. $DBI::errstr\n";
  # This makes the database connection unicode aware
  $dbh->do(qq{SET NAMES 'utf8';});
  return $dbh;
}

my $dbh = connectdb();
my $cgi = new CGI;

sub get_toc {

my $sql = "select semkey,chaptertitle from chapters order by v,f,c,s1,s2,s3";
my $sth = $dbh->prepare($sql);

$sth->execute();

my ($Semkey,$VfcTitle);

$sth->bind_columns(\$Semkey,\$VfcTitle);

# get the files in the dissemination directory, hash the filenames on "chapter" key.
$dissemDir = "/home/stedt/public_html/dissemination";
$dissemURL = "http://stedt.berkeley.edu/dissemination/";
opendir(DIR, $dissemDir);
@FILES= sort(readdir(DIR)); 
closedir(DIR);

print STDERR "Getting and sorting a list of files in $dissemDir\n\n";
my %Filelist;
grep {
     if (/pdf/) {
         my ($volume,$fascicle,$chapter,$date,$version,$draft,$filetype) = /^(\d+)\-(\d+)\-(\d+)\-(\d+)(\-\d+)?(-draft)?\.(pdf|html)/;
         $id = join('.',$volume,$fascicle,$chapter);
         $Filelist{$id} = $_ ;
         print STDERR "id: $id file: $_\n";
         }
     } @FILES;

print STDERR "\n\nLatest versions of each to be included in catalog:\n\n";
while ( (my $key, my $value) = each %Filelist) {
  print STDERR "$key = $value\n";
}

my $result = "<table border=\"1\"><tr><th>VFC<th>Title<th>File";
while ($sth->fetch()) {
  if ($Filelist{$Semkey}) {
    my $chapter = $cgi->a({-href=>$dissemURL . $Filelist{$Semkey},
			 -target=>'reflexes'},$Filelist{$Semkey}) ;
    $result .= "<tr><td>" . join("<td>",($Semkey,b($VfcTitle),$chapter));
    }
}
$result .= "</table>";

return $result ;
}

#STEDTUtil::make_header($cgi,'Electronic Dissemination of STEDT Etymologies');

$overview = <<EndXML;
The following "electronic etymologies" are preliminary publications and subject to revision. Caveat lector!
EndXML

$termsofuse = <<EndXML;
This is a TEST version of the database and its associated software.
Terms of use are forthcoming; at the moment these documents are strictly experimental and not for general use.
<p/>
EndXML

print $cgi->table(
  #$cgi->Tr($cgi->td($cgi->h2('Electronic Dissemination of STEDT Etymologies'))),
  #$cgi->Tr($cgi->td($overview)),
  #$cgi->Tr($cgi->td($cgi->h2('Terms of Use'))),
  #$cgi->Tr($cgi->td($termsofuse)),
  #$cgi->Tr($cgi->td($cgi->h2("Table of Contents"))),
  $cgi->Tr($cgi->td("as of: ", scalar localtime)),
  get_toc($dbh)),"\n";

$dbh->disconnect;

#STEDTUtil::make_footer($cgi);

print STDERR "\nDone at " . (scalar localtime) . "\n";

