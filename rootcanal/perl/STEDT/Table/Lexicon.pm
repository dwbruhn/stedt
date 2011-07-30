package STEDT::Table::Lexicon;
use base STEDT::Table;
use strict;

=pod
This is the magic command that we first tried to use to select lexicon records
based on the content of lx_et_hash and generate analysis fields on the fly.
The join condition(s) restrict the found analyses to, e.g., the STEDT user,
which we have arbitrarily chosen to be uid 8.

SELECT ***DISTINCT*** lexicon.rn,
	GROUP_CONCAT(analysis_table.tag_str ORDER BY analysis_table.ind),
	lexicon.reflex, lexicon.gloss
FROM lexicon
	***LEFT JOIN lx_et_hash ON (lexicon.rn = lx_et_hash.rn AND lx_et_hash.uid=8)***
	LEFT JOIN lx_et_hash AS analysis_table ON (lexicon.rn = analysis_table.rn AND analysis_table.uid=8)
	LEFT JOIN lx_et_hash AS an2 ON (analysis_table.rn = an2.rn AND analysis_table.ind = an2.ind AND an2.uid=1)
WHERE ***lx_et_hash.tag=[[TAG]]***
GROUP BY lexicon.rn ***,lx_et_hash.ind***

The parts in ***'s are necessary if you want to search by tag. The
extra WHERE clause is obviously to search by tag, but that means you
need another JOIN in the FROM. Then, to prevent multiple rows for
records that have been tagged multiple times with the same etymon
(e.g. a reduplicated form u-u for EGG), we add the additional GROUP BY
to expand the record set to have a result row for each value of ind,
thus causing GROUP_CONCAT to concatenate the sequence of tag_str's
once for each time the tag is found. Finally, the DISTINCT modifier
collapses those extra result rows into each other.

Unfortunately, to get a second user's tagging, there does not seem to be
an easy way to do a second join at the same time while disentangling it
from the first; in fact, it may not be possible (remember that there might
be user tagging but no stedt tagging, so you can't piggyback the second join
onto the first). Luckily, subqueries come to the rescue:

(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis

This avoids the need to do DISTINCT or an extra GROUP BY, allows you to retrieve
an unlimited (for all practical purposes) number of user columns, and actually
appears to be more efficient since it saves the extra GROUP BY processing time.


On the other hand, searching by tag is still more efficient using a JOIN
vs. a subquery. Look at this query with a subquery (note the WHERE clause):

SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	lexicon.reflex, lexicon.gloss
FROM lexicon
WHERE lexicon.rn IN (SELECT rn FROM lx_et_hash WHERE uid=8 AND tag=[[TAG]])
GROUP BY lexicon.rn

This is equivalent, but it seems to be over 180 times slower!


A second kind search is one where we want to pull out multiple taggers' analyses
at the same time.

SELECT
	lexicon.rn, an_tbl.uid,
	GROUP_CONCAT(an_tbl.tag_str ORDER BY an_tbl.ind) as analysis,
	lexicon.reflex, lexicon.gloss
FROM lexicon
	LEFT JOIN lx_et_hash AS an_tbl ON (lexicon.rn = an_tbl.rn)
WHERE gloss LIKE 'body%'
GROUP BY lexicon.rn, an_tbl.uid

This will return a separate row for each combination of rn/uid, that is
a separate row containing each analysis belonging to a record.
=cut

sub new {

# STEDT::Table::Lexicon looks for an additional, optional $uid. If specified,
# there will be an additional column returned giving the analyses belonging
# to that uid; saving a new analysis will also use this uid.
# In practice, we usually pass 0 just to suppress display of the second column,
# and non-zero values are just for "authorizers" modifying other people's tags.

my ($self, $dbh, $privs, $uid) = @_;
$uid = 0 if $uid == 8;
	# set this so that below, if $uid has non-zero value,
	# we generate a second analysis column

my $t = $self->SUPER::new($dbh, 'lexicon', 'lexicon.rn', $privs); # dbh, table, key, privs

$t->query_from(q|lexicon LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid)|);
$t->order_by('languagegroups.ord, languagenames.lgsort, lexicon.reflex, languagenames.srcabbr, lexicon.srcid');
$t->fields(
	'lexicon.rn',
	'(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis',
	($uid ? "(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid) AS user_an" : () ),
	'languagenames.lgid',
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.gfn',
	'languagenames.language',
	'languagegroups.grpid',
	'languagegroups.grpno',
	'languagegroups.grp',
	'languagenames.srcabbr', 'lexicon.srcid',
#	'lexicon.semcat',
	'(SELECT COUNT(*) FROM notes WHERE rn=lexicon.rn) AS num_notes'
);
$t->searchable('lexicon.rn', 'analysis', 'user_an', 'lexicon.reflex',
	'lexicon.gloss', 'languagenames.language', 'languagegroups.grp',
	'languagegroups.grpid',
	'languagenames.srcabbr', 'lexicon.srcid',
#	'lexicon.semcat', 
	'lexicon.lgid', 
);
$t->field_visible_privs(
	'user_an' => 1,
);
$t->field_editable_privs(
	'analysis' => 16,
	'user_an' => 1,
	'lexicon.reflex' => 1,
	'lexicon.gloss' => 16,
	'lexicon.gfn' => 16,
	'lexicon.srcid' => 16,
	'lexicon.semcat' => 16, 
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
  								-default=>'', # -override=>1,
  								-labels=>\%grp_labels);
	}
);

$t->wheres(
	'languagegroups.grpid' => 'int',
	'lexicon.lgid' => 'int',
	'analysis' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') { # use special value of 0 to search for empty analysis
			return "0 = (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8)";
		} else {
			my $is_string = ($v !~ /^\d+$/);
			unless ($t->{query_from} =~ / lx_et_hash ON \(lexicon.rn/) {
				$t->{query_from} .= ' LEFT JOIN lx_et_hash ON (lexicon.rn = lx_et_hash.rn AND lx_et_hash.uid=8)';
			}
			$v = '' if $v eq '\\\\'; # hack to find empty tag_str using a backslash
			return $is_string ? "lx_et_hash.tag_str='$v'" : "lx_et_hash.tag=$v";
		}
	},
	'user_an' => sub {
		my ($k,$v) = @_;
		$v =~ s/\D//g; return "'bad int!'='0'" unless $v =~ /\d/;
		if ($v eq '0') {
			return "0 = (SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid)";
		} else {
			my $is_string = ($v !~ /^\d+$/);
			unless ($t->{query_from} =~ / lx_et_hash AS l_e_h2 ON \(lexicon.rn/) {
				$t->{query_from} .= " LEFT JOIN lx_et_hash AS l_e_h2 ON (lexicon.rn = l_e_h2.rn AND l_e_h2.uid=$uid)";
			}
			return $is_string ? "l_e_h2.tag_str='$v'" : "l_e_h2.tag=$v";
		}
	},
	'lexicon.gloss' => 'word',#sub { my ($k,$v) = @_; "$k RLIKE '[[:<:]]$v'" },
	'languagegroups.grp' => sub {my ($k,$v) = @_; $v =~ s/(\.0)+$//; "languagegroups.grpno LIKE '$v\%'"},
		# make it search all subgroups as well
	'languagenames.language' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "lexicon.lgid=0";
		} else {
			return "$k RLIKE '[[:<:]]$v'";
		}
	},
);


$t->save_hooks(
	'analysis' => sub {
		my ($rn, $s) = @_;
		# simultaneously update lx_et_hash
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, 8);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, tag_str, uid) VALUES (?, ?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/, */, $s)) { # Split the contents of the field on commas
			# Insert new records into lx_et_hash based on the updated analysis field
			my $tag_str = $tag;
			$tag = 0 unless ($tag =~ /^\d+$/);
			$sth->execute($rn, $tag, $index, $tag_str, 8);
			$index++;
		}
		# for old time's sake, save this in the analysis field too
		my $update = qq{UPDATE lexicon SET analysis=? WHERE rn=?};
		my $update_sth = $dbh->prepare($update);
		$update_sth->execute($s, $rn);
		return 0;
	},
	'user_an' => sub {
		my ($rn, $s) = @_;
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, $uid);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, tag_str, uid) VALUES (?, ?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/, */, $s)) {
			my $tag_str = $tag;
			$tag = 0 unless ($tag =~ /^\d+$/);
			$sth->execute($rn, $tag, $index, $tag_str, $uid);
			$index++;
		}
		return 0;
	}
);

$t->footer_extra(sub {
	my $cgi = shift;
	# special utility to replace etyma tags
	print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
var x = document.getElementById('update_form').elements;
var r = new RegExp('\\\\b' + document.getElementById('oldtag').value + '\\\\b', 'g');
for (i=0; i< x.length; i++) {
	if (x[i].name.match(/^analysis/)) {
		x[i].value = x[i].value.replace(r,document.getElementById('newtag').value)
	}
}
return false;
EOF
	print $cgi->textfield(-id=>'oldtag',-name =>'oldtag', -size =>4 ),
		$cgi->textfield(-id=>'newtag', -name =>'newtag', -size =>4 ),
		$cgi->submit(-name=>'Replace Tags');
	print $cgi->end_form;
});

# Add form stuff
$t->addable(
	'lexicon.lgid',
	'lexicon.srcid',
	'analysis',
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.gfn',
	'lexicon.semcat',
);

$t->add_form_items(
	'lexicon.lgid' => sub {
		my $cgi = shift;
		my $self_url = $cgi->url(-absolute=>1);
		# make a list of srcabbr's which have one or more languages
		my $a = $dbh->selectall_arrayref("SELECT srcabbr, COUNT(lgid) as numlgs FROM srcbib LEFT JOIN languagenames USING (srcabbr) GROUP BY srcabbr HAVING numlgs > 0 ORDER BY srcabbr");
		return $cgi->popup_menu(-name => 'srcabbr-ignore',
			-values=>[0, map {$_->[0]} @$a],
			-labels=>{'0'=>'(Select...)'},
			-default=>'', -override=>1,
			-id=>'add_srcabbr',
			-onChange => <<EOF) .
new Ajax.Request('$self_url/json_lg/' + \$('add_srcabbr').value, {
	method: 'get',
    onSuccess: function(transport){
		var response = transport.responseText;
		var recs = response.evalJSON();
		var lg_menu = \$('add_language');
		lg_menu.options.length = 0;
		for (var i=0; i<recs.length; i++) {
			lg_menu.options[i] = new Option(recs[i][1],recs[i][0]);
		}
    },
    onFailure: function(){ alert('Error when attempting to retrieve language names.') }
});
EOF
			$cgi->popup_menu(-name=>'lexicon.lgid',
				-values=>[''],
				-id=>'add_language'
			);
	},
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Language not specified!\n" unless $cgi->param('lexicon.lgid');
	$err .= "Reflex is empty!\n" unless $cgi->param('lexicon.reflex');
	$err .= "Gloss is empty!\n" unless $cgi->param('lexicon.gloss');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(500);

return $t;
}

1;
