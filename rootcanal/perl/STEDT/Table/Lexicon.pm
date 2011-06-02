package STEDT::Table::Lexicon;
use base STEDT::Table;
use strict;

sub new {
my $t = shift->SUPER::new(my $dbh = shift, 'lexicon', 'lexicon.rn'); # dbh, table, key

$t->query_from(q|lexicon LEFT JOIN lx_et_hash AS analysis_table USING (rn) LEFT JOIN notes USING (rn) LEFT JOIN languagenames USING (lgid) LEFT JOIN languagegroups USING (grpid)|);
$t->order_by('languagegroups.ord, languagenames.lgsort, lexicon.reflex, languagenames.srcabbr, lexicon.srcid');
$t->fields(
	'lexicon.rn',
#	'lexicon.analysis',
	'GROUP_CONCAT(analysis_table.tag_str ORDER BY analysis_table.ind) AS analysis',
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
	'COUNT(notes.noteid) AS num_notes'
);
$t->searchable('lexicon.rn', 'lexicon.analysis','lexicon.reflex',
	'lexicon.gloss', 'languagenames.language', 'languagegroups.grp',
	'languagegroups.grpid',
	'languagenames.srcabbr', 'lexicon.srcid',
	'lexicon.semcat', 
	'lexicon.lgid', 
);
$t->editable(
	'lexicon.analysis',
	'lexicon.reflex',
	'lexicon.gloss',
	'lexicon.srcid',
	'lexicon.semcat', 
);

$t->wheres(
	'languagegroups.grpid' => 'int',
	'lexicon.lgid' => 'int',
	'analysis' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "$k=''";
		} else {
			# also DISTINCT
			# also GROUP BY
			$t->{query_from} .= ' LEFT JOIN lx_et_hash USING (rn)'
				unless $t->{query_from} =~ / lx_et_hash USING \(rn\)$/;
			return "lx_et_hash.tag=$v";
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

# Special handling of results
$t->update_form_items(
	'languagenames.srcabbr' => sub {
		my ($cgi,$s,$key) = @_;
		return $cgi->a({-href=>"srcbib.pl?submit=Search&srcbib.srcabbr=$s", -target=>'srcbib'},
						$s);
	},
	'COUNT(notes.noteid)' => sub {
		my ($cgi,$n,$key) = @_;
		return $cgi->a({-href=>"notes.pl?L=$key", -target=>'noteswindow'},
			$n == 0 ? "add..." : "$n note" . ($n == 1 ? '' : 's'));
	}
);

$t->print_form_items(
	'COUNT(notes.noteid)' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? '' : "$n note" . ($n == 1 ? '' : 's');
	}
);

$t->save_hooks(
	'lexicon.analysis' => sub {
		my ($rn, $s, $uid) = @_;
		# simultaneously update lx_et_hash
		$dbh->do('DELETE FROM lx_et_hash WHERE rn=? AND uid=?', undef, $rn, $uid);
		my $sth = $dbh->prepare(qq{INSERT INTO lx_et_hash (rn, tag, ind, uid) VALUES (?, ?, ?, ?)});
		my $index = 0;
		for my $tag (split(/, */, $s)) { # Split the contents of the field on contents
			# Insert new records into lx_et_hash based on the updated analysis field
			$sth->execute($rn, $tag, $index, $uid) if ($tag =~ /^\d+$/);
			$index++;
		}
	}
);

$t->footer_extra(sub {
	my $cgi = shift;
	# special utility to replace etyma tags
	print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
var x = document.getElementById('update_form').elements;
var r = new RegExp('\\\\b' + document.getElementById('oldtag').value + '\\\\b', 'g');
for (i=0; i< x.length; i++) {
	if (x[i].name.match(/^lexicon.analysis/)) {
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
	'lexicon.analysis',
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
    onSuccess: function(transport,json){
		var lg_menu = \$('add_language');
		lg_menu.options.length = 0;
		for (var i=0; i<json.ids.length; i++) {
			lg_menu.options[i] = new Option(json.names[i],json.ids[i]);
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
