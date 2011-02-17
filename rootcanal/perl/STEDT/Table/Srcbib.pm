package STEDT::Table::Srcbib;
use base STEDT::Table;
use strict;

sub new {
my $t = shift->SUPER::new(my $dbh = shift, 'srcbib', 'srcbib.srcabbr');

$t->query_from('srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)');
$t->order_by('srcbib.srcabbr, srcbib.year'); # default is the key

$t->fields(
	'srcbib.srcabbr',
	'COUNT(DISTINCT languagenames.lgid) AS num_lgs',
	'COUNT(lexicon.rn) AS num_recs',
	'srcbib.citation',	# seems kinda useless; format looks like last name + two digits of year + some kind of abbrev.
	'srcbib.author',
	'srcbib.year',
	'srcbib.title',
	'srcbib.imprint',	# this is the "rest" of the bibliography line, after author + year + title.
	'srcbib.status',	# looks important: Fix Xcripn, Incomplete, Input, Loaded, No Stack, PI only, Proof, TBEntr'd, etc.
#	'srcbib.location',	# looks useless
	'srcbib.notes',
	'srcbib.todo',		# Complete, Defer, Eval, InQueue, Refonly
#	'srcbib.dataformat',# looks useless: mostly STAK vs. TEXT
	'srcbib.format',	# Art./Monograph, Dictionary, Etymologies, Grammar, Other, Questionnaire, Synonym Sets, Wordlist, Wordlist (Computer), Wordlist (Jianzhi)
#	'srcbib.haveit',	# looks vaguely useless
#	'srcbib.proofer',	# ignoring these... for now.
#	'srcbib.inputter',
#	'srcbib.dbprep',
#	'srcbib.dbload',
#	'srcbib.dbcheck',
#	'srcbib.callnumber',
#	'srcbib.scope',
#	'srcbib.refonly',
#	'srcbib.citechk',
#	'srcbib.pi',
#	'srcbib.totalnum',
#	'srcbib.infascicle',	# added by DY

);
$t->searchable(	'srcbib.srcabbr',
	'srcbib.citation',
	'srcbib.author',
	'srcbib.title',
);
$t->editable(
#	     'srcbib.citation',
	     'srcbib.author',
	     'srcbib.year',
	     'srcbib.title',
	     'srcbib.imprint',
	     'srcbib.status',
#	     'srcbib.location',
	     'srcbib.notes',
	     'srcbib.todo',
#	     'srcbib.dataformat',
	     'srcbib.format',
#	     'srcbib.haveit',
#	     'srcbib.proofer',
#	     'srcbib.inputter',
);

$t->wheres(
	'srcbib.srcabbr' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	protogloss	=> 'word',
	tags		=> 'word',
	pages		=> 'word',
);


$t->addable(
		'srcbib.srcabbr',
#	    'srcbib.citation',
	    'srcbib.author',
	    'srcbib.year',
	    'srcbib.title',
	    'srcbib.imprint',
	    'srcbib.notes',
	    'srcbib.status',
#	    'srcbib.location',
	    'srcbib.todo',
#	    'srcbib.dataformat',
	    'srcbib.format',
#	    'srcbib.haveit',
#	    'srcbib.proofer',
#	    'srcbib.inputter',
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "srcabbr not specified!\n" unless $cgi->param('srcbib.srcabbr');
	$err .= "Author not specified!\n" unless $cgi->param('srcbib.author');
	$err .= "Year name not specified!\n" unless $cgi->param('srcbib.year');
	$err .= "Title not specified!\n" unless $cgi->param('srcbib.title');
	$err .= "imprint not specified!\n" unless $cgi->param('srcbib.imprint');
	return $err;
});


return $t;
}

1;
