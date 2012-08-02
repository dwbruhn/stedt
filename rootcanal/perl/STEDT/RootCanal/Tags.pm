package STEDT::RootCanal::Tags;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use STEDT::RootCanal::Notes;
use CGI::Application::Plugin::Redirect;

sub accept : Runmode {
	my $self = shift;
	unless ($self->has_privs(8)) {
		$self->header_add(-status => 403);
		return "User not allowed to approve tags!";
	}
	my $q = $self->query();
	my $tag = $q->param('tag');
	my $uid = $q->param('uid');
	my $grpno = $q->param('grpno');	# if approving by subgroup
	
	if ($uid !~ /^\d+$/ || $tag !~ /^\d+$/ || (defined($grpno) && $grpno !~ /^[\d.]+$/)) {
		$self->header_add(-status => 400);
		return "Invalid tag/uid/grpno!";
	}
	if ($uid == 8) { # prevent accidental deleting of approved tagging
		$self->header_add(-status => 400);
		return "Already approved!";
	}
	
	# update the etyma record
	my ($old_uid) = $self->dbh->selectrow_array("SELECT uid FROM etyma WHERE tag=$tag");
	$self->dbh->do("UPDATE etyma SET uid=8 WHERE tag=?", undef, $tag);
	$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, owner_uid, time) VALUES (?,?,?,?,?,?,?,NOW())", undef,
			   $self->param('uid'), 'etyma', $tag, 'uid', $old_uid, 8, $old_uid) unless $old_uid == 8;

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

	# get a different list of rn's if approving a subgroup (i.e., if $grpno is defined)
	my ($rns) = (defined $grpno
		? $self->dbh->selectrow_array("SELECT GROUP_CONCAT(DISTINCT lx_et_hash.rn) FROM lx_et_hash LEFT JOIN lexicon ON lx_et_hash.rn=lexicon.rn LEFT JOIN languagenames ON lexicon.lgid=languagenames.lgid LEFT JOIN languagegroups ON languagenames.grpid=languagegroups.grpid WHERE uid=? AND tag=? AND BINARY tag = tag_str AND grpno=?", undef, $uid, $tag, $grpno)
		: $self->dbh->selectrow_array("SELECT GROUP_CONCAT(DISTINCT rn) FROM lx_et_hash WHERE uid=? AND tag=? AND BINARY tag = tag_str", undef, $uid, $tag));
	if ($rns) {
		# figure out changes for the changelog
		# you have to do a LEFT JOIN for the stedt tags in case it's empty
		my $extra_join = (defined $grpno ? "LEFT JOIN languagenames ON lexicon.lgid=languagenames.lgid LEFT JOIN languagegroups ON languagenames.grpid=languagegroups.grpid" : "");
		my $extra_where = (defined $grpno ? "AND grpno='$grpno'" : "");	# extra condition in case of subgroup approval
		my $changed_recs = $self->dbh->selectall_arrayref(<<END);
SELECT lexicon.rn,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=8) AS analysis,
	(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$uid) AS user_an
FROM lexicon
	LEFT JOIN lx_et_hash AS leh1 ON (lexicon.rn=leh1.rn AND leh1.uid=8)
	JOIN lx_et_hash AS leh2 ON (lexicon.rn=leh2.rn AND leh2.uid=$uid)
	$extra_join
WHERE leh2.tag=$tag AND BINARY leh2.tag = leh2.tag_str $extra_where
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
	
	# figure out the "selected" user for the second col, if specified
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

	# pull out the etyma record, along with its mesoroots in the etyma table
	my $sql = qq#SELECT e.tag, e.chapter, e.sequence, e.protoform, e.protogloss, languagegroups.plg,
						e.tag=e.supertag AS is_main, e.uid, users.username
FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag LEFT JOIN users ON (e.uid=users.uid) LEFT JOIN languagegroups ON (e.grpid=languagegroups.grpid)
WHERE e.supertag=? AND e.status != 'DELETE' AND super.status != 'DELETE'
ORDER BY is_main DESC#;
	my $etyma_for_tag = $self->dbh->selectall_arrayref($sql, undef, $tag);
	if (!@$etyma_for_tag) {
		# if it failed the first time, this is probably a mesoroot.
		# get the mesoroot's supertag and redirect to it
		($tag) = $self->dbh->selectrow_array("SELECT supertag FROM etyma WHERE tag=? AND status != 'DELETE'", undef, $tag);
		if (!$tag) {
			die "no etymon with tag #" . $self->param('tag');
		}
		return $self->redirect($self->query->url(-absolute=>1) . "/etymon/$tag" . ($selected_uid ? "/$selected_uid" : ''));
	}

	# pull together a list of users who have tagged this root,
	# and choose a sensible default for the "selected" user if not specified yet
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
	my $supertag = $etyma_for_tag->[0][0];
	my $supertag_done = 0;
	my $breadcrumbs;
	{
		my ($v, $f, $c, $s1, $s2) = split /\./, $etyma_for_tag->[0][1];
		$breadcrumbs = $self->dbh->selectall_arrayref("SELECT semkey, chaptertitle FROM chapters
			WHERE v=? AND (f=? OR f=0) AND (c=? OR c=0) AND (s1=? OR s1=0) AND (s2=? OR s2=0) ORDER BY v,f,c,s1,s2,s3", undef,
			$v, $f||0, $c||0, $s1||0, $s2||0);
	}
	
	if ($selected_uid) {
		# OK to concatenate the uid into the query since we've made sure it's just digits
		$user_analysis_col = "(SELECT GROUP_CONCAT(tag_str ORDER BY ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid=$selected_uid) AS user_an,
			(SELECT GROUP_CONCAT(CONCAT(uid, ':', tag_str) ORDER BY uid,ind) FROM lx_et_hash WHERE rn=lexicon.rn AND uid!=8 AND uid!=$selected_uid) AS other_an,";
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
		@e{qw/tag chap sequence protoform protogloss plg is_main uid username/} = @$_;
		$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";
	
		$e{protoform} =~ s/⪤ +/⪤ */g;
		$e{protoform} =~ s/OR +/OR */g;
		$e{protoform} =~ s/~ +/~ */g;
		$e{protoform} =~ s/ = +/ = */g;
		$e{protoform} = '*' . $e{protoform};
		
		# etymon notes
		$e{notes} = [];
		foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username, id FROM notes LEFT JOIN users USING (uid) "
				. "WHERE tag=$e{tag} AND notetype != 'F' ORDER BY ord")}) {
			my $notetype = $_->[1];
			my $xml = $_->[3];
			next if $notetype eq 'I' && !$INTERNAL_NOTES;
			push @{$e{notes}}, { noteid=>$_->[0], type=>$notetype, lastmod=>$_->[2], 'ord'=>$_->[4],
				text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
				markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
				uid=>$_->[5], username=>$_->[6], id=>$_->[7] # id is grpid in spec=E context
			};
		}
# 		
# 		# mesoroots
# 		foreach (@{$self->dbh->selectall_arrayref("SELECT mesoroots.tag,grpid,grpno,form,gloss,noteid FROM mesoroots LEFT JOIN notes ON (mesoroots.tag=notes.tag AND mesoroots.grpid=notes.id) LEFT JOIN languagegroups USING (grpid) WHERE mesoroots.tag=$e{tag}",
# 			, {Slice=>{}})}) {
# 			push @{$e{mesoroots}}, $_;
# 		}

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
	languagenames.language, languagegroups.grpno, languagegroups.grp,
	languagenames.srcabbr, lexicon.srcid,
	(SELECT COUNT(*) FROM notes WHERE notes.rn = lexicon.rn) AS num_notes
FROM lexicon
	JOIN lx_et_hash ON (lexicon.rn=lx_et_hash.rn AND (lx_et_hash.uid=8 $user_analysis_where))
	LEFT JOIN languagenames USING (lgid)
	LEFT JOIN languagegroups ON (languagenames.grpid=languagegroups.grpid)
WHERE (lx_et_hash.tag = $e{tag}
	$no_meso
)
GROUP BY lexicon.rn
ORDER BY languagegroups.grpno, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
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
			($selected_uid ? ('user_an', 'other_an') : ()),
			'languagenames.lgid', 'lexicon.reflex', 'lexicon.gloss', 'lexicon.gfn',
			'languagenames.language', 'languagegroups.grpno', 'languagegroups.grp',
			'languagenames.srcabbr', 'lexicon.srcid', 'notes.rn'],
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

# for a given tag, return a list of errors that would prevent its deletion.
# returns empty string if all OK.
sub delete_check0 : Runmode {
	my $self = shift;
	my $tag = $self->query->param('tag');
	die "invalid tag '$tag'!\n" unless $tag =~ s/^(\d+)$/$1/;
	my $sql = qq#SELECT
			(SELECT COUNT(DISTINCT tag) FROM etyma WHERE supertag=e.tag AND tag != e.tag) AS num_mesoroots,
			(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=e.tag) AS num_recs,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag=e.tag) AS num_notes
		FROM `etyma` AS `e`
		WHERE e.tag=$tag#;
	my @a = $self->dbh->selectrow_array($sql);
	my @errs = (
		'has # mesoroot(s).',
		'has # record(s) tagged to it.',
		'has # note(s).'
	);
	for my $i (reverse 0..2) {
		if ($a[$i]) {
			$errs[$i] =~ s/#/$a[$i]/;
		} else {
			splice @errs, $i, 1;
		}
	}
	return join "\n", @errs;
}

sub hilite_text {
	my ($s,$tag) = @_;
	$s =~ s|(?<!/)\b$tag\b(?!">)|<span class="cognate">$tag</span>|g; # try not to mess up links by checking for '/' before and '">' after
	$s =~ s|(<a href="[^"]+$tag")>|$1 class="cognate">|g; # hilite the entire link
	return $s;
}

sub delete_check : Runmode {
	my $self = shift;
	my $tag = $self->query->param('tag');
	die "invalid tag '$tag'!\n" unless $tag =~ s/^(\d+)$/$1/;
	my $sql = qq#SELECT tag, 
			(SELECT COUNT(DISTINCT tag) FROM etyma WHERE supertag=e.tag AND tag != e.tag) AS num_mesoroots,
			(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=e.tag AND uid=8) AS num_recs,
			protoform, protogloss, plg,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag=e.tag) AS num_notes,
			(SELECT GROUP_CONCAT(DISTINCT notes.noteid) FROM notes WHERE tag != e.tag AND xmlnote RLIKE CONCAT('<xref ref="',e.tag,'">')) AS xref_notes,
			(SELECT GROUP_CONCAT(DISTINCT notes.noteid) FROM notes WHERE tag != e.tag AND xmlnote NOT RLIKE CONCAT('<xref ref="',e.tag,'">') AND xmlnote RLIKE CONCAT('[[:<:]]',e.tag,'[[:>:]]')) AS other_notes
		FROM `etyma` AS e LEFT JOIN languagegroups USING (grpid)
		WHERE e.tag=$tag#;

	# etymon notes
	my $e = @{$self->dbh->selectall_arrayref($sql, {Slice=>{}})}[0];
	$e->{allow_delete} = ($e->{num_recs}==0 && $e->{num_mesoroots}==0 && $e->{num_notes}==0 && $e->{num_xrefs}==0);

	# the code for compiling notes into a format to pass to notes_etyma.tt, etc. could possibly be put into a subroutine somehow. Search for "SELECT noteid" to see similar code.... tho, each instance is slightly different.
	if ($e->{other_notes} || $e->{xref_notes}) {
		$e->{footnotes} = [];
		$e->{footnote_index} = 1;
		if ($e->{xref_notes}) {
			foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username, id, rn, tag, spec FROM notes LEFT JOIN users USING (uid) "
					. "WHERE noteid IN ($e->{xref_notes})")}) {
				my $notetype = $_->[1];
				my $xml = $_->[3];
				push @{$e->{notes}}, { noteid=>$_->[0], type=>$notetype, lastmod=>$_->[2], 'ord'=>$_->[4],
					text=>hilite_text(xml2html($xml, $self, $e->{footnotes}, \$e->{footnote_index}, $_->[0]), $tag),
						# note that this hiliting will be lost if the user edits the note!
					markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
					uid=>$_->[5], username=>$_->[6], id=>$_->[7],
					rn=>$_->[8], tag=>$_->[9], spec=>$_->[10]
				};
			}
		}
		if ($e->{other_notes}) {
			foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username, id, rn, tag, spec FROM notes LEFT JOIN users USING (uid) "
					. "WHERE noteid IN ($e->{other_notes})")}) {
				my $notetype = $_->[1];
				my $xml = $_->[3];
				push @{$e->{notes}}, { noteid=>$_->[0], type=>$notetype, lastmod=>$_->[2], 'ord'=>$_->[4],
					text=>hilite_text(xml2html($xml, $self, $e->{footnotes}, \$e->{footnote_index}, $_->[0]), $tag),
						# note that this hiliting will be lost if the user edits the note!
					markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
					uid=>$_->[5], username=>$_->[6], id=>$_->[7],
					rn=>$_->[8], tag=>$_->[9], spec=>$_->[10]
				};
			}
		}
		foreach (@{$e->{footnotes}}) {
			$_->{text} = hilite_text($_->{text}, $tag);
		}
	}
	return $self->tt_process("admin/etyma_delete_check.tt", $e);
}

sub soft_delete : Runmode {
	my $self = shift;
	$self->require_privs(1); # for soft delete
	my $tag = $self->query->param('tag');
	die "invalid tag '$tag'!\n" unless $tag =~ s/^(\d+)$/$1/;
	my $sql = qq#SELECT
			(SELECT COUNT(DISTINCT tag) FROM etyma WHERE supertag=e.tag AND tag != e.tag) AS num_mesoroots,
			(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=e.tag AND uid=8) AS num_recs,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag=e.tag) AS num_notes,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag != e.tag AND xmlnote RLIKE CONCAT('<xref ref="',e.tag,'">')) AS num_xrefs
		FROM `etyma` AS e
		WHERE e.tag=$tag#;
	my @a = $self->dbh->selectrow_array($sql);
	if (grep {$_} @a) {
		die "unable to delete #$tag because there are still records/notes associated with it!\n";
	}
	my $merge_tag = $self->query->param('merge_tag')||0 + 0;
	$merge_tag ||= '';
	$self->dbh->do("UPDATE etyma SET status='DELETE', xrefs='$merge_tag' WHERE tag=$tag");
	return '';
}

sub delete_check_all : Runmode {
	my $self = shift;
	my $sql = qq#SELECT tag, 
			(SELECT COUNT(DISTINCT tag) FROM etyma WHERE supertag=e.tag AND tag != e.tag) AS num_mesoroots,
			(SELECT COUNT(DISTINCT rn) FROM lx_et_hash WHERE tag=e.tag AND uid=8) AS num_recs,
			protoform, protogloss, plg,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag=e.tag) AS num_notes,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag != e.tag AND xmlnote RLIKE CONCAT('<xref ref="',e.tag,'">')) AS num_xrefs,
			(SELECT COUNT(DISTINCT notes.noteid) FROM notes WHERE tag != e.tag AND xmlnote NOT RLIKE CONCAT('<xref ref="',e.tag,'">') AND xmlnote RLIKE CONCAT('[[:<:]]',e.tag,'[[:>:]]')) AS other_notes
		FROM `etyma` AS `e` LEFT JOIN languagegroups ON (e.grpid=languagegroups.grpid)
		WHERE status='DELETE' HAVING num_mesoroots > 0 OR num_recs > 0 OR num_notes > 0 OR num_xrefs > 0 OR other_notes > 0#;
	my $etyma = $self->dbh->selectall_arrayref($sql, {Slice=>{}});
	return $self->tt_process("admin/etyma_delete_check_all.tt", {etyma=>$etyma});
}

1;