package STEDT::Table::Etyma;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'etyma', 'etyma.tag', $privs); # dbh, table, key, privs

$t->query_from(q|etyma JOIN `etyma` AS `super` ON etyma.supertag = super.tag LEFT JOIN `users` ON etyma.uid = users.uid LEFT JOIN languagegroups ON etyma.grpid=languagegroups.grpid|);
$t->order_by('super.chapter, super.sequence, IF(super.sequence,0,super.tag), is_mesoroot, languagegroups.grpno');
$t->fields('etyma.tag',
	'etyma.supertag',
#	'etyma.exemplary',
	'(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid=8) AS num_recs',
	($uid ? "(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid=$uid) AS u_recs" : ()),
	($uid ? "(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=etyma.tag AND uid !=8 AND uid != $uid) AS o_recs" : ()),
	'etyma.chapter',
	'etyma.sequence',
	'etyma.protoform', 'etyma.protogloss',
	'etyma.tag!=etyma.supertag AS is_mesoroot',
	'etyma.grpid',
	'languagegroups.plg',
	'languagegroups.grpno',
#	'etyma.semkey',
	'etyma.notes',
	'(SELECT COUNT(*) FROM notes WHERE tag=etyma.tag) AS num_notes',
	'(SELECT COUNT(*) FROM notes WHERE tag=etyma.tag AND notetype="F") AS num_comparanda',
	#'etyma.xrefs',
	'etyma.status',
	'etyma.prefix',
	'etyma.initial',
	'etyma.rhyme',
	'etyma.tone',
	#'etyma.allofams' ,
	#'etyma.possallo' ,
	'etyma.public',
	'users.username',
);
$t->field_visible_privs(
	# 'etyma.supertag' => 1,
	'etyma.chapter' => 3,
	'etyma.notes' => 1,
	'etyma.semkey'  => 1,
	#'etyma.xrefs' => 1,
	'etyma.status' => 1,
	'etyma.prefix' => 1,
	'etyma.initial' => 1,
	'etyma.rhyme' => 1,
	'etyma.tone' => 1,
	'etyma.exemplary' => 1,
	'etyma.sequence'  => 3,
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
	'etyma.sequence',
	'etyma.protoform', 'etyma.protogloss',
	'etyma.grpid',
	'etyma.notes',
#	'etyma.semkey',
	#'etyma.xrefs',#'etyma.possallo','etyma.allofams'	# search these and tagging note and notes DB before deleting records. Also switch to OR searching below.
	'etyma.status',
	'num_notes',
	'etyma.prefix',
	'etyma.initial',
	'etyma.rhyme',
	'etyma.tone',
	'etyma.public',
);
$t->field_editable_privs(
	'etyma.supertag' => 1,
	'etyma.sequence' => 8,
	'etyma.chapter' => 1,
	'etyma.protoform' => 1,
	'etyma.protogloss' => 1,
	'etyma.grpid' => 1,
	'etyma.notes' => 1,
	'etyma.prefix' => 1,
	'etyma.initial' => 1,
	'etyma.rhyme' => 1,
	'etyma.tone' => 1,
	'etyma.status' => 1,
	#'etyma.xrefs' => 16,
	'etyma.possallo' => 16,
	'etyma.semkey' => 16,
	'etyma.allofams' => 16,
	'etyma.public' => 16,
	'etyma.exemplary' => 9,
);

# Stuff for searching
$t->search_form_items(
	'etyma.prefix' => sub {
		my $cgi = shift;
		# get list of prefixs
		my $prefix = $dbh->selectall_arrayref("SELECT DISTINCT prefix FROM etyma ORDER by prefix");
		return $cgi->popup_menu(-name => 'etyma.prefix', -values=>['', map {@$_} @$prefix], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'etyma.initial' => sub {
		my $cgi = shift;
		# get list of initials
		my $initial = $dbh->selectall_arrayref("SELECT DISTINCT initial FROM etyma ORDER by initial");
		return $cgi->popup_menu(-name => 'etyma.initial', -values=>['', map {@$_} @$initial], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'etyma.rhyme' => sub {
		my $cgi = shift;
		# get list of rhymes
		my $rhyme = $dbh->selectall_arrayref("SELECT DISTINCT rhyme FROM etyma ORDER BY rhyme");
		return $cgi->popup_menu(-name => 'etyma.rhyme', -values=>['', map {@$_} @$rhyme], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'etyma.tone' => sub {
		my $cgi = shift;
		# get list of tones
		my $tone = $dbh->selectall_arrayref("SELECT DISTINCT tone FROM etyma ORDER by tone");
		return $cgi->popup_menu(-name => 'etyma.tone', -values=>['', map {@$_} @$tone], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'etyma.grpid' => sub {
		my $cgi = shift;
		my $a = $dbh->selectall_arrayref("SELECT CONCAT(grpno, ' - ', plg), grpid FROM languagegroups WHERE plg != '' ORDER BY grpno");
		unshift @$a, ['', ''];
		push @$a, ['(undefined)', 0];
		my @ids = map {$_->[1]} @$a;
		my %labels;
		@labels{@ids} = map {$_->[0]} @$a;
		return $cgi->popup_menu(-name => 'etyma.grpid', -values=>[@ids],
  								-default=>'',
  								-labels=>\%labels);
	}
);

$t->wheres(
	'etyma.tag' => sub {my ($k,$v) = @_;
		if ($v eq 'm') {return 'etyma.tag!=etyma.supertag'}
		if ($v eq '!m') {return 'etyma.tag=etyma.supertag'}
		'(' . STEDT::Table::where_int($k,$v) . ' OR ' . STEDT::Table::where_int('etyma.supertag',$v) . ')'},
	'etyma.grpid'	=> 'int',
	'etyma.chapter' => sub { my ($k,$v) = @_; $v eq '0' ? "$k=''" : "$k LIKE '$v'" },
	'etyma.protogloss' => 'word',
	'etyma.prefix' => 'value',
	'etyma.initial' => 'value',
	'etyma.rhyme' => 'value',
	'etyma.tone' => 'value',
	'etyma.sequence'  => sub {
		my ($k,$v) = @_;
		if ($v =~ /^(\d+)([a-i])?$/) {
			my ($num, $letter) = ($1, $2);
			if ($letter) {
				return "super.sequence = $num." . (ord($letter) - ord('a') + 1);
			}
			return "FLOOR(super.sequence) = $num";
		}
		return "super.sequence > 0";
	},
	'etyma.semkey' => 'value',
);

$t->save_hooks(
	# this is really more of an "add" hook, not a save hook,
	# but the tag will presumably only ever be set when adding a new record
	# SO, we take this opportunity to set the supertag and the uid
	'etyma.tag' => sub {
		my ($id, $value) = @_;
		# simultaneously set the supertag field
		my $sth = $dbh->prepare(qq{UPDATE etyma SET supertag=tag,uid=? WHERE tag=?});
		$sth->execute($uid, $id);
	},
	'etyma.supertag' => sub {
		my ($id, $value) = @_;
		$value ||= $id; # default to undoing mesoroot if value not specified
		# make sure supertag is a valid value
		# and while we're at it, retrieve the supertag's chapter.
		my $chapter;
		unless (defined($chapter = $dbh->selectrow_array("SELECT chapter FROM etyma WHERE tag=?", undef, $value))) {
			die "Invalid supertag number.\n";
		}
		# move to end if un-mesoing.
		my $seq = 0;
		if ($value == $id && $chapter) {
			$seq = 1 + $dbh->selectrow_array('SELECT FLOOR(MAX(sequence)) FROM etyma WHERE chapter=?', undef, $chapter);
		} else {
			my $super_is_main = $dbh->selectrow_array("SELECT tag=supertag FROM etyma WHERE tag=?", undef, $value);
			unless ($super_is_main) {
				die "The super-root cannot be a mesoroot!\n";
			}
			my $has_subroots = 1 < $dbh->selectrow_array("SELECT COUNT(*) FROM etyma WHERE supertag=?", undef, $id);
			if ($has_subroots) {
				die "Can't make into a mesoroot because it has mesoroots under itself!\n";
			}
		}
		my $sth = $dbh->prepare(qq{UPDATE etyma SET supertag=?, chapter=?, sequence=? WHERE tag=?});
		$sth->execute($value, $chapter, $seq, $id);
		return 0;
	},
);

$t->reload_on_save(
	'etyma.grpid'
);

# Add form stuff
$t->addable(
	'etyma.tag',
	'etyma.chapter',
	'etyma.protoform',
	'etyma.protogloss',
	'etyma.grpid',
	'etyma.notes',
	'etyma.semkey',
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
	'etyma.grpid' => sub {
		my $cgi = shift;
		my $a = $dbh->selectall_arrayref("SELECT CONCAT(grpno, ' - ', plg), grpid FROM languagegroups WHERE plg != '' ORDER BY grpno");
		push @$a, ['(undefined)', 0];
		my @ids = map {$_->[1]} @$a;
		my %labels;
		@labels{@ids} = map {$_->[0]} @$a;
		return $cgi->popup_menu(-name => 'etyma.grpid', -values=>[@ids],
  								-default=>'2',
  								-labels=>\%labels);
	}
);
$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Chapter not specified!\n" unless $cgi->param('etyma.chapter');
	$err .= "Protoform is empty!\n" unless $cgi->param('etyma.protoform');
	$err .= "Protogloss is empty!\n" unless $cgi->param('etyma.protogloss');
	$err .= "Protolanguage not specified!\n" unless $cgi->param('etyma.grpid');
	return $err;
});


#$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
