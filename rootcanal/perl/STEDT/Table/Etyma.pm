package STEDT::Table::Etyma;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'etyma', 'etyma.tag', $privs); # dbh, table, key, privs

$t->query_from(q|etyma JOIN `etyma` AS `super` ON etyma.supertag = super.tag LEFT JOIN `users` ON etyma.uid = users.uid|);
$t->order_by('super.chapter, super.sequence, etyma.plgord');
$t->fields('etyma.tag',
	'etyma.supertag',
	'etyma.printseq' ,
	'(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid=8) AS num_recs',
	($uid ? "(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid=$uid) AS u_recs" : ()),
	($uid ? "(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid !=8 AND uid != $uid) AS o_recs" : ()),
	'etyma.chapter', 'etyma.protoform', 'etyma.protogloss',
	'etyma.plg', 'etyma.plgord',
	'etyma.notes', 'etyma.hptbid',
	'(SELECT COUNT(*) FROM notes WHERE tag=etyma.tag) AS num_notes',
	'etyma.sequence' ,
	'etyma.xrefs',
	'etyma.allofams' ,
	'etyma.possallo' ,
	'etyma.public',
	'users.username',
);
$t->field_visible_privs(
	'etyma.supertag' => 1,
	'etyma.chapter' => 1,
	'etyma.plg' => 1,
	'etyma.notes' => 1,
	'etyma.hptbid' => 1,
	'etyma.xrefs' => 1,
	'etyma.exemplary' => 1,
	'etyma.sequence'  => 1,
	'etyma.possallo'  => 1,
	'etyma.allofams'  => 1,
	'etyma.public' => 1,
	'u_recs' => 1,
	'o_recs' => 1,
	'users.username' => 1,
);
$t->searchable('etyma.tag',
	'num_recs',
	'etyma.chapter',
	'etyma.protoform', 'etyma.protogloss',
	'etyma.plg', 'etyma.notes', 'etyma.printseq',
	'etyma.xrefs',#'etyma.possallo','etyma.allofams'	# search these and tagging note and notes DB before deleting records. Also switch to OR searching below.
	'num_notes',
	'etyma.public',
);
$t->field_editable_privs(
	'etyma.supertag' => 1,
	'etyma.printseq' => 16,
	'etyma.sequence' => 16,
	'etyma.chapter' => 1,
	'etyma.protoform' => 1,
	'etyma.protogloss' => 1,
	'etyma.plg' => 1,
	'etyma.notes' => 1,
	'etyma.hptbid' => 1,
	'etyma.xrefs' => 16,
	'etyma.possallo' => 16,
	'etyma.allofams' => 16,
	'etyma.public' => 16,
);

# Stuff for searching
$t->search_form_items(
	'etyma.plg' => sub {
		my $cgi = shift;
		# get list of proto-lgs
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM etyma");
		if ($plgs->[0][0] eq '') {
			# indexes 0,0 relies on sorted list of plgs.
			# allow explicit searching for empty strings
			# see 'wheres' sub, below
			$plgs->[0][0] = '0';
		}
		
		return $cgi->popup_menu(-name => 'etyma.plg', -values=>['', map {@$_} @$plgs], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->wheres(
	'etyma.tag' => sub {my ($k,$v) = @_; '(' . STEDT::Table::where_int($k,$v) . ' OR ' . STEDT::Table::where_int('etyma.supertag',$v) . ')'},
	'etyma.plg'	=> sub {my ($k,$v) = @_; $v = '' if $v eq '0'; "$k LIKE '$v'"},
	'etyma.chapter' => sub { my ($k,$v) = @_; $v eq '0' ? "$k=''" : "$k LIKE '$v'" },
	'etyma.protogloss'	=> 'word',
	'etyma.printseq'=> sub { my ($k,$v) = @_; "$k RLIKE '^${v}[abc]*\$'" },
	'etyma.hptbid' => sub {
		my ($k,$v) = @_;
		if ($v eq '0') {
			return "$k=''";
		} else {
			return "$k RLIKE '[[:<:]]${v}[[:>:]]'";
		}
	},
);

$t->save_hooks(
	'etyma.printseq' => sub {
		my ($id, $value) = @_;
		# simultaneously update sequence fld
		my ($num, $c) = $value =~ /^(\d+)(.*)/;
		$c = ord($c) - ord('a') + 1 if $c;
		my $sth = $dbh->prepare(qq{UPDATE etyma SET etyma.sequence=? WHERE etyma.tag=?});
		$sth->execute("$num.$c", $id);
	},
	'etyma.hptbid' => sub {
		my ($tag, $s) = @_;
		# simultaneously update et_hptb_hash
		$dbh->do('DELETE FROM et_hptb_hash WHERE tag=?', undef, $tag);
		my $sth = $dbh->prepare(qq{INSERT INTO et_hptb_hash (tag, hptbid, ord) VALUES (?, ?, ?)});
		my $index = 0;
		for my $id (split(/, */, $s)) {
			$sth->execute($tag, $id, $index) if ($id =~ /^\d+$/);
			$index++;
		}
	},
	'etyma.plg' => sub {
		my ($id, $value) = @_;
		# simultaneously update plgord fld
		my @plgs = ('PST', 'PTB', 'KMR', 'PTani', 'AMD', 'PKC',
			'KCN', 'PKN', 'PNC', 'PCC', 'PPC', 'PSPC', 'PNN', 'NNA', 'NAG', 'PBG',
			'HIM', 'PHM', 'WHI', 'BOD', 'TGTM', 'KIR', 'PKir', 'BSD', 'PQ',
			'Jg/Lu', 'LUI', 'PLB', 'LB', 'BRM', 'PBM', 'PL', 'KAR', 'PKar', 'OC',
			'IA', 'NPL');
		my $i;
		$i++ until ($value eq shift @plgs) || !@plgs;
		# this has the side effect of making plgs that aren't on this list sort last.
		
		my $sth = $dbh->prepare(qq{UPDATE etyma SET etyma.plgord=? WHERE etyma.tag=?});
		$sth->execute($i, $id);
	},
	# this is really more of an "add" hook, not a save hook,
	# but the tag will presumably only ever be set when adding a new record
	# SO, we take this opportunity to set the supertag and the uid
	'etyma.tag' => sub {
		my ($id, $value) = @_;
		# simultaneously set the supertag field
		my $sth = $dbh->prepare(qq{UPDATE etyma SET supertag=tag,uid=? WHERE tag=?});
		$sth->execute($uid, $id);
	},
);
$t->footer_extra(sub {
	my $cgi = shift;
	# special utility to renumber printseq
    print $cgi->start_form(-onsubmit=><<EOF); # escape \\ once for perl, once for js
var x = document.getElementById('update_form').elements;
var r = new RegExp('\\\\d+', 'g');
var n = document.getElementById('startfrom').value;
var old_n = 0;
for (i=0; i< x.length; i++) {
	if (x[i].name.match(/^etyma.printseq/)) {
		var a = x[i].value.match(/\\d+/); if (old_n == 0) old_n = a[0];
		if (a[0] != old_n) n++;
		x[i].value = x[i].value.replace(r,n)
		old_n = a[0];
	}
}
return false;
EOF
	print "starting from ", $cgi->textfield(-id=>'startfrom',-name =>'startfrom', -size =>4 ),
		"... ",
		$cgi->submit(-name=>'Renumber printseq');
	print $cgi->end_form;
});

# Add form stuff
$t->addable(
	'etyma.tag',
	'etyma.chapter',
	'etyma.protoform',
	'etyma.protogloss',
	'etyma.plg',
	'etyma.notes',
	'etyma.hptbid',
	'etyma.printseq' ,
);
$t->add_form_items(
	'etyma.tag' => sub {
		my $cgi = shift;
		my $tags = $dbh->selectall_arrayref("SELECT tag FROM etyma ORDER BY tag");
		my @a;	# available tag numbers
		my $i = shift @$tags;
		$i = $i->[0];
		foreach (@$tags) {
			$_ = $_->[0];
			next if ++$i == $_;
			$i--; # reset
			while (++$i < $_) {
				push @a, $i;
			}
		}
		$i++;
		return $cgi->popup_menu(-name => 'etyma.tag', -values=>['',$i,@a],  -default=>'', -override=>1);
	},
	'etyma.plg' => sub {
		my $cgi = shift;
		my $plgs = $dbh->selectall_arrayref("SELECT DISTINCT plg FROM etyma");
		return $cgi->popup_menu(-name => 'etyma.plg', -values=>[map {@$_} @$plgs],  -default=>'PTB', -override=>1);
	}
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Chapter not specified!\n" unless $cgi->param('etyma.chapter');
	$err .= "Protoform is empty!\n" unless $cgi->param('etyma.protoform');
	$err .= "Protogloss is empty!\n" unless $cgi->param('etyma.protogloss');
	$err .= "Protolanguage is empty!\n" unless $cgi->param('etyma.plg');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
