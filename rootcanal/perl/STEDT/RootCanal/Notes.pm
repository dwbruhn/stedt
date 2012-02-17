package STEDT::RootCanal::Notes;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use utf8;
use CGI::Application::Plugin::Redirect;
use Time::HiRes qw(time);

sub chapter_browser : StartRunMode {
	my $self = shift;
	my $t0 = time();
	my $tweak = $self->param('tweak');
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
	unless ($self->has_privs(1)) {
		$public = "AND etyma.public=1";
		$blessed = 'AND etyma.uid=8';
		$public_ch = 'HAVING num_public OR public_notes';
	}
	# from the chapters table
	my $chapterquery = <<SQL;
SELECT chapters.semkey, chapters.chaptertitle, 
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND public=1 $blessed) AS num_public,
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey $blessed),
	COUNT(DISTINCT notes.noteid), MAX(notes.notetype = 'G'), MAX(notes.notetype != 'I') as public_notes,
        chapters.semcat, chapters.old_chapter, chapters.old_subchapter, chapters.id
        XXXX
FROM chapters LEFT JOIN notes ON (notes.id=chapters.semkey) LEFT JOIN glosswords ON (chapters.semkey=glosswords.semkey)
GROUP BY 1 $public_ch ORDER BY v,f,c,s1,s2,s3
SQL
	# this query is extremely slow in "tweak mode" (i.e. when the glosswords for each VFC are looked up)
	# the hack below 'reverts' the query to its faster version.
	if ($tweak eq 'tweak') {
	  # allow long GROUP_CONCAT's.
	  # see comment below under &accept.
	  my (undef, $max_len) = $self->dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name='max_allowed_packet'");
	  die "oops couldn't get max_allowed_packet from mysql" unless $max_len;
	  $self->dbh->do("SET SESSION group_concat_max_len = $max_len");
	  my $clause = ",
COUNT(DISTINCT glosswords.word),
GROUP_CONCAT(DISTINCT glosswords.word SEPARATOR ', ') AS some_glosswords,
(SELECT COUNT(*) FROM lexicon WHERE lexicon.semkey=chapters.semkey) AS wcount";
	  $chapterquery =~ s/XXXX/$clause/m;
	}
	elsif ($tweak eq 'grid') {
	  # grid will need v, f, and c ... but not the expensive join on keywords
	  $chapterquery =~ s/XXXX/,v,f,c/m;
	  $chapterquery =~ s/ LEFT JOIN glosswords ON \(chapters.semkey=glosswords.semkey\)//m;
	  # order by fascicle 1st, so we can output a table easily.
	  $chapterquery =~ s/ORDER BY v,f,c,s1,s2,s3/ORDER BY f,v,c,s1,s2,s3/m;
	}
	else {
	  $chapterquery =~ s/XXXX//m;
	  $chapterquery =~ s/ LEFT JOIN glosswords ON \(chapters.semkey=glosswords.semkey\)//m;
	}
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);
	# chapters that appear in etyma but not in chapters table
	my $e_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT etyma.chapter, SUM(etyma.public), COUNT(*)
FROM etyma LEFT JOIN chapters ON (etyma.chapter=chapters.semkey)
WHERE chapter != ''  $public $blessed AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL
	# chapters that appear in notes but not in chapters table
	my $n_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT notes.id, COUNT(notes.noteid), COUNT(etyma.tag)
FROM notes LEFT JOIN chapters ON (notes.id=chapters.semkey) LEFT JOIN etyma ON (etyma.chapter=chapters.semkey)
WHERE notes.spec='C' AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL

	my $tt;
	if ($tweak eq 'tweak') {
	  $tt = 'chapter_tweaker.tt';
	}
	elsif ($tweak eq 'grid') {
	  $tt = 'semantic_grid.tt';
	}
	else {
	  $tt = 'chapter_browser.tt';
	}
	return $self->tt_process($tt, {
		ch=>$chapters, e=>$e_ghost_chaps, n=>$n_ghost_chaps, time_elapsed=>sprintf("%0.3g", time()-$t0)
	});
}

sub chapter : RunMode {
	my $self = shift;
	my $tag = $self->param('tag');
	my $chap = $self->param('chap');
	my $title = $self->dbh->selectrow_array("SELECT chaptertitle FROM chapters WHERE semkey=?", undef, $chap);
	$title ||= '[chapter does not exist in chapters table!]';
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid)"
			. "WHERE spec='C' AND id=? $internal_note_search ORDER BY ord", undef, $chap)}) {
		my $xml = $_->[3];
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
			uid=>$_->[5], username=>$_->[6]
		};
	}
	
	my $t = $self->load_table_module('etyma');
	my $q = $self->query->new('');
	$q->param('etyma.chapter'=>$chap);
	$q->param('etyma.sequence'=>'>0'); # hide non-sequenced items from the chapter view
	$q->param('etyma.public'=>1) unless $self->has_privs(1);
	my $result = $t->search($q);
	
	return $self->tt_process("chapter.tt", {
		chap => $chap, chaptitle=>$title,
		notes  => \@notes,
		footnotes => \@footnotes,
		result => $result
	});
}

sub add : RunMode {
	my $self = shift;
	unless ($self->has_privs(1)) {
		$self->header_add(-status => 403);
		return "User not logged in" unless $self->param('user');
		return "User not allowed to add notes!";
	}
	my $dbh = $self->dbh;
	my $q = $self->query;
	my ($spec, $id, $ord, $type, $xml, $uid) = ($q->param('spec'), $q->param('id'),
		$q->param('ord'), $q->param('notetype'), decode_utf8(markup2xml($q->param('xmlnote'))), $q->param('uid'));
	my $key = $spec eq 'L' ? 'rn' : $spec eq 'E' ? 'tag' : 'id';
	if ($uid != 8 && $uid != $self->param('uid')) {
		# force uid to be either 8 or the current user's uid
		$uid = $self->param('uid');
	}
	my $sth = $dbh->prepare("INSERT notes (spec, $key, ord, notetype, xmlnote, uid) VALUES (?,?,?,?,?,?)");
	$sth->execute($spec, $id, $ord, $type, $xml, $uid);

	my $kind = $spec eq 'L' ? 'lex' : $spec eq 'C' ? 'chapter' : # special handling for comparanda
		$spec eq 'S' ? 'source' : $type eq 'F' ? 'comparanda' : 'etyma';
	my $noteid = $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
	my $lastmod = $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=?", undef, $noteid);
	$self->header_add('-x-json'=>qq|{"id":"$noteid"}|);
	my @a; my $i = $q->param('fn_counter')+1;
	return join "\r", ${$self->tt_process("notes_$kind.tt", {
		n=>{noteid=>$noteid, type=>$type, lastmod=>$lastmod, 'ord'=>$ord,
			text=>xml2html($xml, $self, \@a, \$i, $spec eq 'E' ? $id : undef),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
			uid=>$uid, username=>($uid==8 ? 'stedt' : $self->param('user'))
			},
		fncounter=>$q->param('fn_counter')
	})}, map {$_->{text}} @a;
}

sub delete : RunMode {
	my $self = shift;
	$self->require_privs(1);
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	if ($self->param('uid') != $note_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to delete someone else's note.";
	}
	
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {
		my $sql = "DELETE FROM notes WHERE noteid=?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($noteid);
	} else {
		$self->dbh->do("UNLOCK TABLES");
		$self->header_add(-status => 409);
 		return "Someone else has modified this note (since $lastmod)! The note was not deleted.";
 	}
	$self->dbh->do("UNLOCK TABLES");
	return '';
}

sub save : RunMode {
	my $self = shift;
	$self->require_privs(1);
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	my $xml;

	# only allow taggers to modify their own notes
	if ($self->param('uid') != $note_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to modify someone else's note.";
	}
	
	# check mod time to ensure no one changed it before us
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {
		my $sql = "UPDATE notes SET notetype=?, xmlnote=? WHERE noteid=?";
		my @args = ($q->param('notetype'), markup2xml($q->param('xmlnote')));
		if ($q->param('id')) { # actually an optional tag number, for lexicon notes
			$sql =~ s/ WHERE/, id=? WHERE/;
			push @args, $q->param('id');
		}
		if ($q->param('uid')) {
			$sql =~ s/ WHERE/, uid=? WHERE/;
			push @args, $q->param('uid');
		}
		my $sth = $dbh->prepare($sql);
		$sth->execute(@args, $noteid);
		($xml, $lastmod) = $dbh->selectrow_array("SELECT xmlnote, datetime FROM notes WHERE noteid=?", undef, $noteid);
	} else {
		$self->dbh->do("UNLOCK TABLES");
		$self->header_add(-status => 409);
 		return "Someone else has modified this note! Your changes were not saved.";
 	}
	$self->dbh->do("UNLOCK TABLES");
	$self->header_add('-x-json'=>qq|{"lastmod":"$lastmod"}|);
	my @a; my $i = 1;
	return join("\r", xml2html($xml, $self, \@a, \$i), map {$_->{text}} @a);
}

sub reorder : RunMode {
	my $self = shift;
	$self->require_privs(8);
	my @ids = map {/(\d+)$/} split /\&/, $self->query->param('ids');
	# change the order, but don't update the modification time for something so minor.
	my $sth = $self->dbh->prepare("UPDATE notes SET ord=?, datetime=datetime WHERE noteid=?");
	my $i = 0;
	$sth->execute(++$i, $_) foreach @ids;
	return '';
}

sub xml2markup {
	local $_ = $_[0];
	s|^<par>||;
	s|</par>$||;
	s|</par><par>|\n\n|g;
	s|<br />|\n|g;
	s|<sup>(.*?)</sup>|[[^$1]]|g;
	s|<sub>(.*?)</sub>|[[_$1]]|g;
	s|<emph>(.*?)</emph>|[[~$1]]|g;
	s|<strong>(.*?)</strong>|[[\@$1]]|g;
	s|<gloss>(.*?)</gloss>|[[:$1]]|g;
	s|<reconstruction>\*(.*?)</reconstruction>|[[*$1]]|g;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|[[#$1$2]]|g;
	s|<a href="(.*?)">(.*?)</a>|[[!$1 $2]]|g;
	s|<footnote>(.*?)</footnote>|{{%$1}}|g;
	s|<hanform>(.*?)</hanform>|[[$1]]|g;
	s|<latinform>(.*?)</latinform>|[[+$1]]|g;
	s|<plainlatinform>(.*?)</plainlatinform>|[[$1]]|g;
	s/&amp;/&/g;
	s/&lt;/</g;
	s/&gt;/>/g;
	s/&apos;/'/g;
	s/&quot;/"/g;
	return $_;
}

sub guess_num_lines {
	use integer;
	my $n = length($_[0])/70;
	return $n < 3 ? 3 : $n;
}

# markup2xml returns encoded (binary) utf8, you may need to decode
my $LEFT_BRACKET = encode_utf8('⟦');
my $RIGHT_BRACKET = encode_utf8('⟧');
sub markup2xml {
	my $s = shift;
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/'/&apos;/g;
	$s =~ s/"/&quot;/g;
	$s =~ s/(?<!\[)\[([^\[\]]*)\]/$LEFT_BRACKET$1$RIGHT_BRACKET/g;
		# take out matching single square brackets
		# note that this only matches a single level
		# of embedded pairs of single square brackets inside
		# other square brackets. To match more levels from
		# the inside out, repeat several times.
	$s =~ s/\[\[([^\[\]]*?)\]\]/_markup2xml($1)/ge foreach (1..2);
		# no recursion (embedded square brackets);
		# if needed eventually, run multiple times
		#	while ($s =~ s/\[\[([^\[\]]*?)\]\]/_markup2xml($1)/ge) {}
	$s =~ s/$LEFT_BRACKET/[/go; # restore single square brackets
	$s =~ s/$RIGHT_BRACKET/]/go;
	$s =~ s|{{%(.*?)}}|<footnote>$1</footnote>|g;
	$s =~ s|^[\r\n]+||g;
	$s =~ s|[\r\n]+$||g;
	$s =~ s#(\r\n){2,}|\r{2,}|\n{2,}#</par><par>#g;
	$s =~ s#\r\n|\r|\n#<br />#g;
	return "<par>$s</par>";
}

sub _markup2xml {
	my $s = shift;
	my ($code, $s2) = $s =~ /^(.)(.*)/;
	if ($code =~ /[_^~:*+@]/) {
		my %sym2x = qw(_ sub ^ sup ~ emph : gloss * reconstruction @ strong + latinform);
		$s2 = $s if $code eq '*';
		return "<$sym2x{$code}>$s2</$sym2x{$code}>";
	}
	if ($code eq '#') {
		my ($num, $s3) = $s2 =~ /^(\d+)(.*)/;
		return qq|<xref ref="$num">#$num$s3</xref>|;
	}
	if ($code eq '!') {	#if it's a link, pull out the URL and the link text, and make the xml look similar to the <xref> category
		my ($url, $delim, $ltext) = $s2 =~ /^(.+?)( |$)(.*)/;		#matches url followed by space, space+text, or end of line
		if (!$ltext) {	#if the user left the link text blank, make it = url
			$ltext = $url;
		}
		return qq|<a href="$url">$ltext</a>|;
	}
	my $u = ord decode_utf8($s); ### oops, it hasn't been decoded from utf8 yet
	if (($u >= 0x3400 && $u <= 0x4dbf) || ($u >= 0x4e00 && $u <= 0x9fff)
		|| ($u >= 0x20000 && $u <= 0x2a6df)) {
		return "<hanform>$s</hanform>";
	}
	return "<plainlatinform>$s</plainlatinform>";
}

sub _tag2info {
	my ($t, $s, $c) = @_;
	my ($form, $gloss) = $c->dbh->selectrow_array("SELECT etyma.protoform,etyma.protogloss FROM etyma WHERE tag=?", undef, $t);
	return "[ERROR! Dead etyma ref #$t!]" unless $form;
	$form =~ s/-/‑/g; # non-breaking hyphens
	$form =~ s/^/*/;
	$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
	$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
	if ($s) {			# alternative gloss, add it in
		$s = "$form</a> $s";
	} else {
		$s = "$form</a> $gloss"; # put protogloss if no alt given
	}
	my $u = $c->query->url(-absolute=>1);
	return qq|<a href="$u/etymon/$t">#$t $s|;
}

sub _nonbreak_hyphens {
	my $s = $_[0];
	$s =~ s/-/‑/g;
	return $s;
}

my @italicize_abbrevs =
qw|GSR GSTC STC HPTB TBRS TSR AHD VSTB TBT HCT LTBA BSOAS CSDPN TIL OED|;

# this sub is used so that apostrophes in forms are not educated into "smart quotes"
# We need to substitute an obscure unicode char, then switch it back to "&apos;" later.
# Here we use the "full width" variants used in CJK fonts.
sub _qtd {
	my $s = $_[0];
	$s =~ s/&apos;/＇/g;
	$s =~ s/&quot;/＂/g;
	return $s;
}

# returns the note in html; an array of footnotes is added to if there are
# footnotes in the note text.
# The footnotes array is only relevant to notes (e.g. etyma notes, chapter notes)
# that can have footnotes inside them; lexicon notes should not contain footnotes,
# since they are inherently footnotes! However, the $footnotes and $i arguments
# are still obligatory.
#
# first arg: xml to be converted.
# $c: the CGI::App object, so we can pass context info when necessary.
# $footnotes: array ref, to add the converted footnotes, etc. to.
# $i: ref to a footnote number counter, to be incremented for each footnote. Should be initialized to 1.
# $super_id: the note id of the note, to be embedded in the footnote data.

sub xml2html {
	local $_ = shift;
	my ($c, $footnotes, $i, $super_id) = @_;
	s|<par>|<p>|g;
	s|</par>|</p>|g;
	s|<emph>|<i>|g;
	s|</emph>|</i>|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"<b>*" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2,$c)|ge;
	s|<hanform>(.*?)</hanform>|$1|g;
	s|<latinform>(.*?)</latinform>|"<b>" . _nonbreak_hyphens(_qtd($1)) . "</b>"|ge;
	s|<plainlatinform>(.*?)</plainlatinform>|_qtd($1)|ge;

	s/(\S)&apos;/$1’/g; # smart quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	
	s/＇/&apos;/g; # switch back the "dumb" quotes
	s/＂/&quot;/g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s|\b($abbrev)\b|<i>$1</i>|g;
	}
	### specify STEDTU here?

	s/&lt;-+&gt;/⟷/g; # convert arrows
	s/< /< /g; # no-break space after "comes from" sign
	
	s|<footnote>(.*?)</footnote>|push @$footnotes,{text=>$1,super=>$super_id}; qq(<a href="#foot$$i" id="toof$$i"><sup>) . $$i++ . "</sup></a>"|ge;
	s/^<p>//; # get rid of the first pair of (not the surrounding) <p> tags.
	s|</p>||;
	return $_;
}

sub notes_for_rn : Runmode {
	my $self = shift;
	my $rn = $self->query->param('rn');
	return 'Error: not a number' unless $rn =~ /^\d+$/;
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;

	my $notes = $self->dbh->selectall_arrayref("SELECT xmlnote,uid,username FROM notes LEFT JOIN users USING (uid) WHERE rn=? $internal_note_search", undef, $rn);
	my @notes;
	my (@dummy, $dummy);
	for (@$notes) {
		 my $xml = $_->[0];
		 my $uid = $_->[1];
		 $xml .= " [$_->[2]]" unless $uid == 8; # append the username
		 push @notes, xml2html($xml, $self, \@dummy, \$dummy);
	}
	return join '<p>', @notes;
}

sub accept : Runmode {
	my $self = shift;
	unless ($self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to approve tags!";
	}
	my $q = $self->query();
	my $tag = $q->param('tag');
	my $uid = $q->param('uid');
	
	if ($uid !~ /^\d+$/ || $tag !~ /^\d+$/) {
		$self->header_add(-status => 400);
		return "Invalid tag/uid!";
	}
	if ($uid == 8) { # prevent accidental deleting of approved tagging
		$self->header_add(-status => 400);
		return "Already approved!";
	}
	
	# update the etyma record
	$self->dbh->do("UPDATE etyma SET uid=8 WHERE tag=?", undef, $tag);
	my ($old_uid) = $self->dbh->selectrow_array("SELECT uid FROM etyma WHERE tag=$tag");
	$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, owner_uid, time) VALUES (?,?,?,?,?,?,NOW())", undef,
			   $self->param('uid'), 'etyma', $tag, 'uid', $old_uid, 8) unless $old_uid == 8;

	# GROUP_CONCAT has an upper limit (default 1024 bytes) which can be increased to the server max.
	# Since we are expecting a long list here, and since the value of the
	# "IN (...)" is also constrained by the server maximum, increase group_concat_max_len:
	my (undef, $max_len) = $self->dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name='max_allowed_packet'");
	die "oops couldn't get max_allowed_packet from mysql" unless $max_len;
	$self->dbh->do("SET SESSION group_concat_max_len = $max_len");

	# We assume that the list of rn's will not be longer than the server max.
	# In the unfortunate event that this happens, the last rn in the list
	# may be truncated and thus refer to an unrelated root; this rn's tags
	# will get deleted (see DELETE below). Meanwhile, there will be a bunch
	# of rn's whose tags still need approving.
	# It is unlikely that this will happen, but the reader should be aware
	# that the reason we did this is because putting a SELECT inside the
	# IN (...) was prohibitively slow.
	# The alternative is to move the DELETE and UPDATE lines inside the loop
	# and do them for each iteration. This may not be much a performance hit
	# and is guaranteed to not fail.
	my ($rns) = $self->dbh->selectrow_array("SELECT GROUP_CONCAT(DISTINCT rn) FROM lx_et_hash WHERE uid=? AND tag=?", undef, $uid, $tag);
	if ($rns) {
		# figure out changes for the changelog
		# you have to do a LEFT JOIN for the stedt tags in case it's empty
		my $changed_recs = $self->dbh->selectall_arrayref(<<END);
SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid) AS user_an
FROM lexicon
	LEFT JOIN lx_et_hash AS leh1 ON (lexicon.rn=leh1.rn AND leh1.uid=8)
	JOIN lx_et_hash AS leh2 ON (lexicon.rn=leh2.rn AND leh2.uid=$uid)
WHERE leh2.tag=$tag
GROUP BY lexicon.rn
END
		# bless the tagging
		$self->dbh->do("DELETE FROM lx_et_hash WHERE uid=8 AND rn IN ($rns)");
		$self->dbh->do("UPDATE lx_et_hash SET uid=8 WHERE uid=? AND rn IN ($rns)", undef, $uid);
		# add these changes to the changelog
		foreach (@$changed_recs) {
			my ($rn, $old, $new) = @$_;
			$old ||= ''; # in case NULL
			$self->dbh->do("INSERT changelog (uid, change_type, accepted_tag, `table`, id, col, oldval, newval, owner_uid, time) VALUES (?,?,?,?,?,?,?,?,?,NOW())", undef,
					   $self->param('uid'), 'approval', $tag, 'lexicon', $rn, 'analysis', $old, $new, $uid) unless $old eq $new;
		}
	}
	return $self->redirect($q->url(-absolute=>1) . "/etymon/$tag/$uid");
}

# return an etymon page with notes, reflexes, etc.
sub etymon : Runmode {
	my $self = shift;
	my $tag = $self->param('tag');
	my $selected_uid = $self->param('uid2');
	if ($selected_uid ne '' && ($selected_uid !~ /^[1-9]\d*$/ || $selected_uid == 8)) {
		$self->header_add(-status => 400);
		return "Invalid uid requested!"; # non-numeric, or 0, or the stedt uid
	}
	if ($selected_uid && !$self->has_privs(1)) {
		return $self->redirect($self->query->url(-absolute=>1) . "/etymon/$tag");
	}
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my (@etyma, @footnotes, @users);
	my $footnote_index = 1;
	my $sql = qq#SELECT e.tag, e.chapter, e.sequence, e.protoform, e.protogloss, e.plg,
						e.hptbid, e.tag=e.supertag AS is_main, e.uid, users.username
FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag LEFT JOIN users ON (e.uid=users.uid)
WHERE e.supertag=?
ORDER BY is_main DESC, e.plgord#;
	my $etyma_for_tag = $self->dbh->selectall_arrayref($sql, undef, $tag);
	if (!@$etyma_for_tag) {
		# if it failed the first time, this is probably a mesoroot.
		# get the mesoroot's supertag and redirect to it
		($tag) = $self->dbh->selectrow_array("SELECT supertag FROM etyma WHERE tag=?", undef, $tag);
		if (!$tag) {
			die "no etymon with tag #" . $self->param('tag');
		}
		return $self->redirect($self->query->url(-absolute=>1) . "/etymon/$tag" . ($selected_uid ? "/$selected_uid" : ''));
	}

	my $self_uid = $self->param('uid');
	my $stedt_count = 0;
	my $selected_username;
	if ($self->has_privs(1)) {
		my $self_count = 0;
		my $mosttagged_uid;
		my $userrecs = $self->dbh->selectall_arrayref("SELECT users.uid,username,COUNT(DISTINCT rn) as num_forms, users.uid=8 AS not_stedt FROM users JOIN lx_et_hash USING (uid) JOIN etyma USING (tag) WHERE supertag=? GROUP BY uid ORDER BY not_stedt, num_forms DESC",undef,$tag);
		if (@$userrecs) {
			# get number of stedt records (it's the last row, if it's there)
			if ($userrecs->[-1][0] == 8) {
				$stedt_count = $userrecs->[-1][2];
				pop @$userrecs;
			}
			$mosttagged_uid = $userrecs->[0][0] if @$userrecs; # if no rows, don't make a new blank one implicitly by accessing it
			foreach (@$userrecs) {
				push @users, {uid=>$_->[0], username=>$_->[1], count=>$_->[2]};
				$self_count = $_->[2] if ($_->[0] == $self_uid); # save this value while passing through
			}
		}
	
		# so far, we have
		# $selected_uid: may be '', guaranteed not to be 8
		# $mosttagged_uid: defined if there are tagged records by any non-stedt account
		# $self_uid: may be 8
		# $self_count: > 0 if there are tagged records by the currently logged in user, unless currently logged in as stedt
		if (!$selected_uid ) {	# no uid specified, so pick a sensible default
			if ($self_count) {	# if you've tagged any records, show your own tags
				$selected_uid = $self_uid;
			} elsif ($mosttagged_uid) {	# otherwise show the user who's tagged most
				$selected_uid = $mosttagged_uid;
			} elsif ($self_uid != 8) {	# no user tagging - show your own so you can tag
				$selected_uid = $self_uid;
			}
		}
		# at this point, if $selected_uid is still undef,
		# it's because $self_uid is 8 and there is no user tagging at all

		# final cleanup: add certain users to the list; set $selected_username
		if ($selected_uid) {
			foreach (@$userrecs) {
				$selected_username = $_->[1] if ($_->[0] == $selected_uid);
			}
			if (!$self_count && $self_uid != 8) {
				# always allow switching to your own tagging
				push @users, {uid=>$self_uid, username=>$self->param('user'), count=>0};
				$selected_username = $self->param('user') if $self_uid == $selected_uid; # set this here since it wasn't in @users
			}
			if (!$selected_username) {
				# if a user who hasn't tagged anything is selected, add them to the popup list
				($selected_username) = $self->dbh->selectrow_array("SELECT username FROM users WHERE uid=?", undef, $selected_uid);
				if (!$selected_username) {
					$self->header_add(-status => 400);
					return "No user for that uid!";
				}
				push @users, {uid=>$selected_uid, username=>$selected_username, count=>0};
			}
		}
	}

	my $user_analysis_col = '';
	my $user_analysis_where = '';
	my $no_meso = '';
	my $supertag = $etyma_for_tag->[0][0] if @$etyma_for_tag;
	my $supertag_done = 0;
	my $breadcrumbs;
	{
		my ($v, $f, $c, $s1, $s2) = split /\./, $etyma_for_tag->[0][1];
		$breadcrumbs = $self->dbh->selectall_arrayref("SELECT semkey, chaptertitle FROM chapters
			WHERE v=? AND (f=? OR f=0) AND (c=? OR c=0) AND (s1=? OR s1=0) AND (s2=? OR s2=0) ORDER BY v,f,c,s1,s2,s3", undef,
			$v, $f||0, $c||0, $s1||0, $s2||0);
	}
	
	if ($selected_uid && @$etyma_for_tag) {
		# OK to concatenate the uid into the query since we've made sure it's just digits
		$user_analysis_col = "(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$selected_uid) AS user_an,";
		$user_analysis_where = "OR lx_et_hash.uid=$selected_uid";

		# if there's two columns, we need to make sure the first column
		# in the superroot section does not contain records tagged with mesoroots,
		# since those will show up later on and we don't want them to appear twice.
		$no_meso = "AND lexicon.rn NOT IN (SELECT lexicon.rn FROM lexicon
			JOIN lx_et_hash AS leh1 ON (lexicon.rn=leh1.rn AND leh1.uid=8)
			JOIN lx_et_hash AS leh2 ON (lexicon.rn=leh2.rn AND leh2.uid=$selected_uid)
			JOIN etyma AS e2 ON (leh2.tag=e2.tag)
		WHERE (leh1.tag=$supertag AND e2.supertag=$supertag AND e2.tag != e2.supertag))";
	}
	foreach (@$etyma_for_tag) {
		my %e; # hash of infos to be added to @etyma
		push @etyma, \%e;
	
		# heading stuff
		@e{qw/tag chap sequence protoform protogloss plg hptbid is_main uid username/} = @$_;
		$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";
	
		$e{protoform} =~ s/⪤ +/⪤ */g;
		$e{protoform} =~ s/OR +/OR */g;
		$e{protoform} =~ s/~ +/~ */g;
		$e{protoform} =~ s/ = +/ = */g;
		$e{protoform} = '*' . $e{protoform};
		
		# etymon notes
		$e{notes} = [];
		my $seen_hptb; # don't generate an HPTB reference if there's a custom HPTB note already
		foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid) "
				. "WHERE tag=$e{tag} AND notetype != 'F' ORDER BY ord")}) {
			my $notetype = $_->[1];
			my $xml = $_->[3];
			next if $notetype eq 'I' && !$INTERNAL_NOTES;
			$seen_hptb = 1 if $notetype eq 'H';
			push @{$e{notes}}, { noteid=>$_->[0], type=>$notetype, lastmod=>$_->[2], 'ord'=>$_->[4],
				text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
				markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
				uid=>$_->[5], username=>$_->[6]
			};
		}
		if ($e{hptbid} && !$seen_hptb) {
			my $text = "See <i>HPTB</i> ";
			my @refs = split /,/, $e{hptbid};
			my @strings;
			for my $id (@refs) {
				my ($pform, $plg, $pages) =
					$self->dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=?", undef, $id);
				my $p = ($pages =~ /,/ ? "pp" : "p");
				push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "<b>$pform</b>, $p. $pages";
			}
			$text .= join('; ', @strings);
			$text .= '.';
			push @{$e{notes}}, {type=>'H', text=>$text};
		}
	
		# do entries
		if ($supertag_done && $no_meso) {
			# for mesoroots, make sure we don't list items that were in the superroot section
			$no_meso = "AND lexicon.rn NOT IN (SELECT lexicon.rn FROM lexicon
				JOIN lx_et_hash AS leh1 ON (lexicon.rn=leh1.rn AND leh1.uid=8)
				JOIN lx_et_hash AS leh2 ON (lexicon.rn=leh2.rn AND leh2.uid=$selected_uid)
			WHERE (leh1.tag=$e{tag} AND leh2.tag=$supertag))";
		}
		$supertag_done = 1;
		my $recs = $self->dbh->selectall_arrayref(<<EndOfSQL);
SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	$user_analysis_col
	languagenames.lgid, lexicon.reflex, lexicon.gloss, lexicon.gfn,
	languagenames.language, languagegroups.grpid, languagegroups.grpno, languagegroups.grp,
	languagenames.srcabbr, lexicon.srcid, languagegroups.ord,
	(SELECT COUNT(*) FROM notes WHERE notes.rn = lexicon.rn) AS num_notes
FROM lexicon
	JOIN lx_et_hash ON (lexicon.rn=lx_et_hash.rn AND (lx_et_hash.uid=8 $user_analysis_where))
	LEFT JOIN languagenames USING (lgid)
	LEFT JOIN languagegroups ON (languagenames.grpid=languagegroups.grpid)
WHERE (lx_et_hash.tag = $e{tag}
	$no_meso
)
GROUP BY lexicon.rn
ORDER BY languagegroups.ord, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
		if (@$recs) { # skip if no records
			collect_lex_notes($self, $recs, $INTERNAL_NOTES, \@footnotes, \$footnote_index, $e{tag});
			$e{records} = $recs;
		}
	
		# Chinese comparanda
		$e{comparanda} = [];
		my $comparanda = $self->dbh->selectall_arrayref("SELECT noteid, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid) WHERE tag=$e{tag} AND notetype = 'F' ORDER BY ord");
		for my $row (@$comparanda) {
			my $note = $row->[2];
#			$note =~ s/(Karlgren|Li|Baxter): /\\hfill $1: /g;
			$note =~ s/ Citations:/<br>Citations:/g;
			$note =~ s/ Correspondences:/<br>Correspondences:/g;
#			$note =~ s/(\[ZJH\])/\\hfill $1/g;
#			$note =~ s/(\[JAM\])/\\hfill $1/g;
			push @{$e{comparanda}}, { noteid=>$row->[0], lastmod=>$row->[1], 'ord'=>$row->[3],
				text=>xml2html($note, $self, \@footnotes, \$footnote_index, $row->[0]),
				markup=>xml2markup($note), num_lines=>guess_num_lines($note),
				uid=>$row->[4], username=>$row->[5]
			};
		}
	}

	return $self->tt_process("etymon.tt", {
		etyma    => \@etyma,
		users    => \@users,
		selected_username => $selected_username, selected_uid => $selected_uid,
		stedt_count => $stedt_count, supertag => $tag,
		fields => ['lexicon.rn', 'analysis',
			($selected_uid ? 'user_an' : ()),
			'languagenames.lgid', 'lexicon.reflex', 'lexicon.gloss', 'lexicon.gfn',
			'languagenames.language', 'languagegroups.grpid', 'languagegroups.grpno', 'languagegroups.grp',
			'languagenames.srcabbr', 'lexicon.srcid', 'languagegroups.ord', 'notes.rn'],
		footnotes => \@footnotes,
		breadcrumbs=>$breadcrumbs
	});
	# @etyma : [
	# 	{
	# 		tag,
	# 		sequence,
	# 		...
	# 		notes : [],
	# 		fields: [],
	# 		records: [],
	# 		comparanda: [],
	# 	}
	# ]
}

# this sub is tacked on here and exposed (via Exporter) so other modules can use it.
# $c: CGI::App obj
# $r: arrayref of arrayrefs (a result set from a lexicon table SQL query)
# $internal: whether or not to show internal notes
# $a, $i: an array ref and a scalar ref. see xml2html for these.
# $tag: tag number if we're restricting notes to those associated with a particular etymon/rn pair.
sub collect_lex_notes {
	my ($c, $r, $internal, $a, $i, $tag) = @_;
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I' AND notetype != 'O'" unless $internal;
	my $tag_search = '';
	$tag_search = "AND (`id`=$tag OR `id`='')" if $tag;
	for my $rec (@$r) {
		if ($rec->[-1]) { # if there are any notes...
			# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
			my @results = @{$c->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, id, uid, username FROM notes LEFT JOIN users USING (uid) "
					. "WHERE notes.rn=? $tag_search $internal_note_search ORDER BY ord",
					undef, $rec->[0])};
			$rec->[-1] = '';
			# NB: these are footnotes, and they don't have footnotes inside them!
			foreach (@results) {
				my ($noteid, $notetype, $lastmod, $note, $id, $uid, $username) = @$_;
				my $xml = $note;
				$note = xml2html($xml, $c, $a, $i);
				if ($notetype eq 'I') {
					$note =~ s/^/[Internal] <i>/;
					$note =~ s|$|</i>|;
				}
				$note =~ s/^/[Source note] / if $notetype eq 'O';
				push @$a, {noteid=>$noteid, type=>$notetype, lastmod=>$lastmod,
					text=>$note, id=>$id, # id is for lex notes specific to particular etyma.
					markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
					uid=>$uid, username=>$username
				};
				$rec->[-1] .= ' ' . $$i++;
			}
		}
		$rec->[-1] ||= '0';
	}
}

1;
