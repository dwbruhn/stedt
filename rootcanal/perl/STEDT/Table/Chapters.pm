package STEDT::Table::Chapters;
use base STEDT::Table;
use strict;

sub new {
my ($self, $dbh, $privs, $uid) = @_;
my $t = $self->SUPER::new($dbh, 'chapters', 'chapters.id', $privs); # dbh, table, key, privs

$t->query_from(q|chapters|);
$t->order_by('chapters.v, chapters.f, chapters.c, chapters.s1, chapters.s2, chapters.s3, chapters.chaptertitle'); # default is the key

$t->fields(
	   'chapters.id',
	   'chapters.chapter',
	   'chapters.chaptertitle',
	   'chapters.chapterabbr',
	   'chapters.v',
	   'chapters.f',
	   'chapters.c',
	   'chapters.s1',
	   'chapters.s2',
	   'chapters.s3',
	   'chapters.semcat',
	   'chapters.old_chapter',
	   'chapters.old_subchapter'
);
$t->searchable(
	   'chapters.chapter',
	   'chapters.chaptertitle',
	   'chapters.v',
	   'chapters.f',
	   'chapters.c',
	   'chapters.s1',
	   'chapters.s2',
	   'chapters.s3',
	   'chapters.semcat',
	   'chapters.old_chapter',
	   'chapters.old_subchapter'
);
$t->editable(
	   'chapters.chapter',
	   'chapters.chaptertitle',
	   'chapters.v',
	   'chapters.f',
	   'chapters.c',
	   'chapters.s1',
	   'chapters.s2',
	   'chapters.s3',
	   'chapters.semcat',
	   'chapters.old_chapter'
);

# Stuff for searching
$t->search_form_items(
	'chapters.v' => sub {
		my $cgi = shift;
		# get list of volumes
		my $vs = $dbh->selectall_arrayref("SELECT DISTINCT v FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.v', -values=>['', map {@$_} @$vs], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'chapters.f' => sub {
		my $cgi = shift;
		# get list of fascicles
		my $fs = $dbh->selectall_arrayref("SELECT DISTINCT f FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.f', -values=>['', map {@$_} @$fs], -labels=>{'0'=>'(no value)'},  -default=>'');
	},
	'chapters.c' => sub {
		my $cgi = shift;
		# get list of chapters
		my $cs = $dbh->selectall_arrayref("SELECT DISTINCT c FROM chapters");
		return $cgi->popup_menu(-name => 'chapters.c', -values=>['', map {@$_} @$cs], -labels=>{'0'=>'(no value)'},  -default=>'');
	}
);

$t->save_hooks(
	       'chapter.semcat' => sub {
		 my ($id, $value) = @_;
		 my $sth = $dbh->prepare(qq{UPDATE chapters SET semcat=? WHERE id=?});
		 $sth->execute($uid, $id);
	       },
);


$t->wheres(
	   'chapters.chapter' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'chapters.chaptertitle' => sub {my ($k,$v) = @_; "$k LIKE '$v\%'"},
	   'chapters.v'	 => 'int',
	   'chapters.f'	 => 'int',
	   'chapters.c'	 => 'int',
	   'chapters.s1' => 'int',
	   'chapters.s2' => 'int',
	   'chapters.s3' => 'int',
);


$t->addable(
	   'chapters.chapter',
	   'chapters.chaptertitle',
	   'chapters.v',
	   'chapters.f',
	   'chapters.c',
	   'chapters.s1',
	   'chapters.s2',
	   'chapters.s3'
);

$t->add_check(sub {
	my $cgi = shift;
	my $err = '';
	$err .= "Chapter name not specified!\n" unless $cgi->param('chapters.chapter');
	$err .= "Chaptertitle name not specified!\n" unless $cgi->param('chapters.chaptertitle');
	return $err;
});


$t->allow_delete(1);
#$t->debug(1);
$t->search_limit(200);

return $t;
}

1;
