package STEDT::Table::Languagenames;
use base STEDT::Table;
use strict;

sub new {
my $t = shift->SUPER::new(my $dbh = shift, 'languagenames', 'languagenames.lgid');

$t->query_from(q|languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid)|);
$t->order_by('languagenames.lgsort');

$t->fields(
	'languagenames.lgid',
	'COUNT(lexicon.rn) AS num_recs',
	'languagenames.srcabbr',
	'languagenames.lgabbr',
	'languagenames.lgcode',
	'languagenames.silcode',
	'languagenames.language',
	'languagenames.lgsort',
	'languagenames.notes',
	'languagenames.srcofdata',
#	'languagenames.pinotes',
#	'languagenames.picode',
	'languagegroups.grpno',
	'languagegroups.grp',
	'languagenames.grpid',
);
$t->searchable(
#	'languagenames.lgid',
	'languagenames.srcabbr',
	'languagenames.language',
#	'languagenames.lgabbr',
	'languagenames.silcode',
	'languagenames.lgcode',
#	'languagenames.lgsort',
	'languagenames.notes',
#	'languagenames.srcofdata',
#	'languagenames.pinotes',
#	'languagenames.picode',
#	'languagegroups.grpno',
	'languagegroups.grp',
	'languagenames.grpid',

);
$t->editable(
	'languagenames.language',
	'languagenames.lgsort'  ,
	'languagenames.notes'   ,
	'languagenames.lgcode',
	'languagenames.srcofdata',
#	'languagenames.pinotes' ,
#	'languagenames.picode'  ,
	'languagenames.grpid'	,
);

# Stuff for searching
$t->search_form_items(
	'languagegroups.grp' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpno, CONCAT(grpno,' ',LEFT(grp,15),' (id:',grpid,')') FROM languagegroups");
		my @grp_nos = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_nos} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagegroups.grp', -values=>['',@grp_nos],
  								-default=>'', -override=>1,
  								-labels=>\%grp_labels);
	}
);

$t->wheres(
	'languagenames.lgid' => 'int',
	'languagenames.lgcode' => 'int',
	'languagenames.grpid' => 'int',
	'languagenames.srcabbr' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	'languagegroups.grp' => sub {my ($k,$v) = @_; $v =~ s/(\.0)+$//; "languagegroups.grpno LIKE '$v\%'"},
		# make it search all subgroups as well
	'languagenames.language' => sub { my ($k,$v) = @_; "$k RLIKE '[[:<:]]$v'"; },
);


$t->footer_extra(sub {
print q|<script type="text/javascript">
TableKit.Editable.selectInput('languagenames.grpid', {}, [|;
# We query the database for the groups three times in this script,
# which is kinda inefficient,
# but there aren't that many groups, so it's OK.
	my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups");
	print join ',',map {"['$_->[1]','$_->[0]']"} @$grps;
print ']);</script>
';
});


# Add form stuff
$t->addable(
	'languagenames.srcabbr',
	'languagenames.lgabbr',
	'languagenames.lgsort',
	'languagenames.language',
	'languagenames.notes',
	'languagenames.srcofdata',
	'languagenames.lgcode',
	'languagenames.grpid',
);
$t->add_form_items(
	'languagenames.srcabbr' => sub {
		my $cgi = shift;
		# list of all srcabbr's
		my $a = $dbh->selectall_arrayref("SELECT srcabbr FROM srcbib ORDER BY srcabbr");
		return $cgi->popup_menu(-name => 'languagenames.srcabbr',
			-values=>['', map {@$_} @$a],
			-labels=>{''=>'(Select...)'},
			-default=>'', -override=>1,
		);
	},
	'languagenames.grpid' => sub {
		my $cgi = shift;
		my $grps = $dbh->selectall_arrayref("SELECT grpid, CONCAT(grpno,' ',grp) FROM languagegroups");
		my @grp_ids = map {$_->[0]} @$grps;
		my %grp_labels;
		@grp_labels{@grp_ids} = map {$_->[1]} @$grps;
		
		return $cgi->popup_menu(-name => 'languagenames.grpid', -values=>['',@grp_ids],
			-default=>'', -override=>1,
			-labels=>\%grp_labels);
	}
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "srcabbr not specified!\n" unless $cgi->param('languagenames.srcabbr');
	$err .= "lgsort not specified!\n" unless $cgi->param('languagenames.lgsort');
	$err .= "Language name not specified!\n" unless $cgi->param('languagenames.language');
	$err .= "Group not specified!\n" unless $cgi->param('languagenames.grpid');
	return $err;
});


$t->allow_delete(1);

return $t;
}

1;
