#!/usr/bin/perl -w

# an example of running local scripts by loading a CGI script

use strict;
use CGI qw/:standard :cgi-lib/;
$ENV{'HOME'} = '/home/stedt-cgi-ssl';
$ENV{'PATH'} = '/usr/local/bin:/usr/bin:/bin:/home/stedt-cgi-ssl:/home/stedt-cgi-ssl/texlive/2010/bin/x86_64-linux';
print header(-charset => "utf8"); # calls charset for free, so forms don't mangle text

if (param('semkey')) {
    my ($v,$f,$c) = split('\.',param('semkey'));

    print "<h2>Running... makeFasc.sh \"$v\" \"$f\" \"$c\" --i</h2>";
    print '<pre>';
    system("/home/stedt-cgi-ssl/rootcanals/makeFasc.sh \"$v\" \"$f\" \"$c\" --i 2>\&1");
    print '</pre>';
    print "<h1>Done!</h1>";
}
else {
    print "<h1>please supply V.F.C. as a parameter, e.g. 'semkey=6.2.1'</h1>";
}
