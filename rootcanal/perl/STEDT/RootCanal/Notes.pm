package STEDT::RootCanal::Notes;
use strict;
use base 'STEDT::RootCanal::Base', 'Exporter';
use Encode;
use utf8;
our @EXPORT = qw(collect_lex_notes);

sub chapter_browser : RunMode {
	my $self = shift;
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
	unless ($self->has_privs(1)) {
		$public = "AND etyma.public=1";
		$blessed = 'AND etyma.uid=8';
		$public_ch = 'HAVING num_public OR public_notes';
	}
	# from the chapters table
	my $chapters = $self->dbh->selectall_arrayref(<<SQL);
SELECT chapters.chapter, chapters.chaptertitle, SUM(etyma.public) AS num_public,
	COUNT(DISTINCT etyma.tag), COUNT(DISTINCT notes.noteid), MAX(notes.notetype = 'G'), MAX(notes.notetype != 'I') as public_notes
FROM chapters LEFT JOIN etyma ON (etyma.chapter=chapters.chapter $blessed)
	LEFT JOIN notes ON (notes.id=chapters.chapter)
GROUP BY 1 $public_ch ORDER BY 1
SQL
	# chapters that appear in etyma but not in chapters table
	my $e_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT etyma.chapter, SUM(etyma.public), COUNT(*)
FROM etyma NATURAL LEFT JOIN chapters
WHERE chapter != ''  $public $blessed AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL
	# chapters that appear in notes but not in chapters table
	my $n_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT notes.id, COUNT(notes.noteid), COUNT(etyma.tag)
FROM notes LEFT JOIN chapters ON (notes.id=chapters.chapter) LEFT JOIN etyma USING (chapter)
WHERE notes.spec='C' AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL
	return $self->tt_process('chapter_browser.tt', {
		ch=>$chapters, e=>$e_ghost_chaps, n=>$n_ghost_chaps
	});
}

sub chapter : RunMode {
	my $self = shift;
	my $tag = $self->param('tag');
	my $chap = $self->param('chap');
	my $title = $self->dbh->selectrow_array("SELECT chaptertitle FROM chapters WHERE chapter=?", undef, $chap);
	$title ||= '[chapter does not exist in chapters table!]';
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord FROM notes "
			. "WHERE spec='C' AND id=? $internal_note_search ORDER BY ord", undef, $chap)}) {
		my $xml = decode_utf8($_->[3]);
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml)
		};
	}
	
	my $t = $self->load_table_module('etyma');
	my $q = $self->query->new;
	$q->param('etyma.chapter'=>$chap);
	$q->param('etyma.public'=>1) unless $self->has_privs(1);
	my $result = $t->search($q, $self->param('userprivs'));
	for my $row (@{$result->{data}}) {
		map {$_ = decode_utf8($_)} @$row; # apparently because we decode_utf8 on some stuff above, we have to do it here too. Compare with Edit/table and edit.tt, where it looks like it's going in binary mode?
	}
	
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
		$self->header_props(-status => 403);
		return "User not logged in" unless $self->param('user');
		return "User not allowed to add notes!";
	}
	my $dbh = $self->dbh;
	my $q = $self->query;
	my ($spec, $id, $ord, $type, $xml) = ($q->param('spec'), $q->param('id'),
		$q->param('ord'), $q->param('notetype'), markup2xml($q->param('xmlnote')));
	my $key = $spec eq 'L' ? 'rn' : $spec eq 'E' ? 'tag' : 'id';
	my $sth = $dbh->prepare("INSERT notes (spec, $key, ord, notetype, xmlnote, uid) VALUES (?,?,?,?,?,?)");
	$sth->execute($spec, $id, $ord, $type, $xml, $self->session->param('uid'));

	my $kind = $spec eq 'L' ? 'lex' : $spec eq 'C' ? 'chapter' : # special handling for comparanda
		$type eq 'F' ? 'comparanda' : 'etyma';
	my $noteid = $dbh->selectrow_array("SELECT LAST_INSERT_ID()");
	my $lastmod = $dbh->selectrow_array("SELECT datetime FROM notes WHERE noteid=?", undef, $noteid);
	$self->header_add('-x-json'=>qq|{"id":"$noteid"}|);
	my @a; my $i = $q->param('fn_counter')+1;
	return join "\r", ${$self->tt_process("notes_$kind.tt", {
		n=>{noteid=>$noteid, type=>$type, lastmod=>$lastmod, 'ord'=>$ord,
			text=>xml2html($xml, $self, \@a, \$i, $spec eq 'E' ? $id : undef),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml)},
		fncounter=>$q->param('fn_counter')
	})}, map {$_->{text}} @a;
}

sub delete : RunMode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	if ($self->session->param('uid') != $note_uid && !$self->has_privs(16)) {
		$self->header_props(-status => 403);
		return "User not allowed to delete someone else's note.";
	}
	
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {
		my $sql = "DELETE FROM notes WHERE noteid=?";
		my $sth = $dbh->prepare($sql);
		$sth->execute($noteid);
	} else {
		$self->dbh->do("UNLOCK TABLES");
		$self->header_props(-status => 409);
 		return "Someone else has modified this note (since $lastmod)! The note was not deleted.";
 	}
	$self->dbh->do("UNLOCK TABLES");
	return '';
}

sub save : RunMode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	my $dbh = $self->dbh;
	my $q = $self->query;
	my $noteid = $q->param('noteid');
	my $lastmod = $q->param('mod');
	my ($mod_time, $note_uid) = $dbh->selectrow_array("SELECT datetime,uid FROM notes WHERE noteid=?", undef, $noteid);
	my $xml;

	# only allow taggers to modify their own notes
	if ($self->session->param('uid') != $note_uid && !$self->has_privs(16)) {
		$self->header_props(-status => 403);
		return "User not allowed to modify someone else's note.";
	}
	
	# check mod time to ensure no one changed it before us
	$dbh->do("LOCK TABLE notes WRITE");
	if ($lastmod eq $mod_time) {
		my $sql = "UPDATE notes SET notetype=?, xmlnote=? WHERE noteid=?";
		my @args = ($q->param('notetype'), markup2xml($q->param('xmlnote')));
		if ($q->param('id')) {
			$sql =~ s/ WHERE/, id=? WHERE/;
			push @args, $q->param('id');
		}
		my $sth = $dbh->prepare($sql);
		$sth->execute(@args, $noteid);
		($xml, $lastmod) = $dbh->selectrow_array("SELECT xmlnote, datetime FROM notes WHERE noteid=?", undef, $noteid);
	} else {
		$self->dbh->do("UNLOCK TABLES");
		$self->header_props(-status => 409);
 		return "Someone else has modified this note! Your changes were not saved.";
 	}
	$self->dbh->do("UNLOCK TABLES");
	$self->header_add('-x-json'=>qq|{"lastmod":"$lastmod"}|);
	my @a; my $i = 1;
	return join("\r", xml2html(decode_utf8($xml), $self, \@a, \$i), map {$_->{text}} @a);
}

sub reorder : RunMode {
	my $self = shift;
	if (my $err = $self->require_privs(16)) { return $err; }
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
	my $u = ord decode_utf8($s); ### oops, it hasn't been decoded from utf8 yet
	if (($u >= 0x3400 && $u <= 0x4dbf) || ($u >= 0x4e00 && $u <= 0x9fff)
		|| ($u >= 0x20000 && $u <= 0x2a6df)) {
		return "<hanform>$s</hanform>";
	}
	return "<plainlatinform>$s</plainlatinform>";
}

sub _tag2info {
	my ($t, $s, $c) = @_;
	my @a = $c->dbh->selectrow_array("SELECT etyma.protoform,etyma.protogloss FROM etyma WHERE tag=?", undef, $t);
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my ($form, $gloss) = map {decode_utf8($_)} @a;
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
	s|<plainlatinform>(.*?)</plainlatinform>|_qtd($1)|g;

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

sub notes_for_rn : StartRunmode {
	my $self = shift;
	my $rn = $self->param('rn');
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;

	my $notes = $self->dbh->selectall_arrayref("SELECT xmlnote,uid,username FROM notes LEFT JOIN users USING (uid) WHERE rn=? $internal_note_search", undef, $rn);
	my @notes;
	my (@dummy, $dummy);
	for (@$notes) {
		 my $xml = decode_utf8($_->[0]);
		 my $uid = $_->[1];
		 $xml .= " [$_->[1]]" unless $uid == 8; # append the username
		 push @notes, xml2html($xml, $self, \@dummy, \$dummy);
	}
	return join '<p>', @notes;
}

# return an etymon page with notes, reflexes, etc.
sub etymon : Runmode {
	my $self = shift;
	my $tag = $self->param('tag');
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my (@etyma, @footnotes);
	my $footnote_index = 1;
	my $sql = qq#SELECT e.tag, e.printseq, e.protoform, e.protogloss, e.plg, e.hptbid, e.tag=e.supertag AS is_main
FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag
WHERE e.supertag=?
ORDER BY is_main DESC, e.plgord#;
	my $etyma_for_tag = $self->dbh->selectall_arrayref($sql, undef, $tag);
	if (!@$etyma_for_tag) {
		# if it failed the first time, this is probably a mesoroot.
		# get the mesoroot's supertag and try one more time
		($tag) = $self->dbh->selectrow_array("SELECT supertag FROM etyma WHERE tag=?", undef, $tag);
		$etyma_for_tag = $self->dbh->selectall_arrayref($sql, undef, $tag);
	}
	if (!@$etyma_for_tag) { die "no etymon with tag #$tag" }

	foreach (@$etyma_for_tag) {
		my %e; # hash of infos to be added to @etyma
		push @etyma, \%e;
	
		# heading stuff
		@e{qw/tag printseq protoform protogloss plg hptbid is_main/}
			= map {decode_utf8($_)} @$_;
		$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";
	
		$e{protoform} =~ s/⪤ +/⪤ */g;
		$e{protoform} =~ s/OR +/OR */g;
		$e{protoform} =~ s/~ +/~ */g;
		$e{protoform} =~ s/ = +/ = */g;
		$e{protoform} = '*' . $e{protoform};
		
		# etymon notes
		$e{notes} = [];
		my $seen_hptb; # don't generate an HPTB reference if there's a custom HPTB note already
		foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord FROM notes "
				. "WHERE tag=$e{tag} AND notetype != 'F' ORDER BY ord")}) {
			my $notetype = $_->[1];
			my $xml = decode_utf8($_->[3]);
			next if $notetype eq 'I' && !$INTERNAL_NOTES;
			$seen_hptb = 1 if $notetype eq 'H';
			push @{$e{notes}}, { noteid=>$_->[0], type=>$notetype, lastmod=>$_->[2], 'ord'=>$_->[4],
				text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
				markup=>xml2markup($xml), num_lines=>guess_num_lines($xml)
			};
		}
		if ($e{hptbid} && !$seen_hptb) {
			my $text = "See <i>HPTB</i> ";
			my @refs = split /,/, $e{hptbid};
			my @strings;
			for my $id (@refs) {
				my ($pform, $plg, $pages) =
					$self->dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=?", undef, $id);
				$pform = decode_utf8($pform);
				my $p = ($pages =~ /,/ ? "pp" : "p");
				push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "<b>$pform</b>, $p. $pages";
			}
			$text .= join('; ', @strings);
			$text .= '.';
			push @{$e{notes}}, {type=>'H', text=>$text};
		}
	
	
		# do entries
		my $recs = $self->dbh->selectall_arrayref(<<EndOfSQL);
SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	languagenames.lgid, lexicon.reflex, lexicon.gloss, lexicon.gfn,
	languagenames.language, languagegroups.grpid, languagegroups.grpno, languagegroups.grp,
	languagenames.srcabbr, lexicon.srcid, languagegroups.ord,
	(SELECT COUNT(*) FROM notes WHERE notes.rn = lexicon.rn) AS num_notes
FROM lexicon
	LEFT JOIN lx_et_hash ON (lexicon.rn=lx_et_hash.rn AND lx_et_hash.uid=8),
	languagenames,
	languagegroups
WHERE (lx_et_hash.tag = $e{tag}
	AND languagenames.lgid=lexicon.lgid
	AND languagenames.grpid=languagegroups.grpid
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
		my $comparanda = $self->dbh->selectall_arrayref("SELECT noteid, datetime, xmlnote, ord FROM notes WHERE tag=$e{tag} AND notetype = 'F' ORDER BY ord");
		for my $row (@$comparanda) {
			my $note = $row->[2];
			$note = decode_utf8($note);
#			$note =~ s/(Karlgren|Li|Baxter): /\\hfill $1: /g;
			$note =~ s/ Citations:/<br>Citations:/g;
			$note =~ s/ Correspondences:/<br>Correspondences:/g;
#			$note =~ s/(\[ZJH\])/\\hfill $1/g;
#			$note =~ s/(\[JAM\])/\\hfill $1/g;
			push @{$e{comparanda}}, { noteid=>$row->[0], lastmod=>$row->[1], 'ord'=>$_->[3],
				text=>xml2html($note, $self, \@footnotes, \$footnote_index, $row->[0]),
				markup=>xml2markup($note), num_lines=>guess_num_lines($note)
			};
		}
	}

	return $self->tt_process("etymon.tt", {
		etyma    => \@etyma,
		fields => ['lexicon.rn', 'analysis', 'languagenames.lgid', 'lexicon.reflex', 'lexicon.gloss', 'lexicon.gfn',
			'languagenames.language', 'languagegroups.grpid', 'languagegroups.grpno', 'languagegroups.grp',
			'languagenames.srcabbr', 'lexicon.srcid', 'languagegroups.ord', 'notes.rn'],
		footnotes => \@footnotes
	});
	# @etyma : [
	# 	{
	# 		tag,
	# 		printseq,
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
		$_ = decode_utf8($_) foreach @$rec; # if even one string is decoded, TT will want *everything* to be decoded, otherwise you'll get garbage utf8
		if ($rec->[-1]) { # if there are any notes...
			# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
			my @results = @{$c->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, id, uid, username FROM notes LEFT JOIN users USING (uid) "
					. "WHERE notes.rn=? $tag_search $internal_note_search ORDER BY ord",
					undef, $rec->[0])};
			$rec->[-1] = '';
			# NB: these are footnotes, and they don't have footnotes inside them!
			foreach (@results) {
				my ($noteid, $notetype, $lastmod, $note, $id, $uid, $username) = @$_;
				my $xml = decode_utf8($note);
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
	}
}

1;
