package STEDT::Table::Etyma;
use base STEDT::Table;
use strict;

sub new {
my $t = shift->SUPER::new(my $dbh = shift, 'etyma', 'etyma.tag'); # dbh, table, key

$t->query_from(q|etyma LEFT JOIN notes USING (tag) LEFT JOIN lx_et_hash USING (tag)|); # ON (notes.spec = 'E' AND notes.id = etyma.tag) 
$t->order_by('etyma.chapter, etyma.sequence, etyma.protogloss'); #printseq+0, etyma.printseq -- this was needed before we made sequence redundant with printseq
$t->fields('etyma.tag',
	'etyma.printseq' ,
	'COUNT(DISTINCT lx_et_hash.rn) AS num_recs',
	'etyma.chapter', 'etyma.protoform', 'etyma.protogloss',
	'etyma.plg', 'etyma.notes', 'etyma.hptbid',
	'COUNT(DISTINCT notes.noteid) AS num_notes',
	'etyma.sequence' ,
	'etyma.exemplary',
	'etyma.xrefs',
	'etyma.allofams' ,
	'etyma.possallo' ,
	'etyma.public',
);
$t->field_visible_privs(
	'etyma.chapter' => 16,
	'etyma.plg' => 16,
	'etyma.notes' => 16,
	'etyma.hptbid' => 16,
	'etyma.xrefs' => 16,
	'etyma.exemplary' => 16,
	'etyma.sequence'  => 16,
	'etyma.possallo'  => 16,
	'etyma.allofams'  => 16,
	'etyma.public' => 16,
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
$t->editable(
	'etyma.chapter', 'etyma.protoform', 'etyma.protogloss',
	'etyma.plg', 'etyma.notes', 'etyma.hptbid',
	'etyma.xrefs',
	'etyma.possallo' ,
	'etyma.allofams' ,
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
		
		return $cgi->popup_menu(-name => 'etyma.plg', -values=>['', map {@$_} @$plgs], -labels=>{'0'=>'(no value)'},  -default=>'', -override=>1);
	}
);

$t->wheres(
	'etyma.plg'	=> sub {my ($k,$v) = @_; $v = '' if $v eq '0'; "$k LIKE '$v'"},
	'etyma.chapter' => sub { my ($k,$v) = @_; "$k LIKE '$v'" },
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
$t->print_form_items(
	'num_notes' => sub {
		my ($cgi,$n,$key) = @_;
		return $n == 0 ? '' : "$n note" . ($n == 1 ? '' : 's');
	}
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
	}
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
