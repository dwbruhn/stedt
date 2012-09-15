package STEDT::RootCanal::Search;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;

sub splash : StartRunmode {
	my $self = shift;
	my $splash_info;
	
	# generate the list of language groups for the dropdown box:
	$splash_info->{grps} = $self->dbh->selectall_arrayref("SELECT grpno, grp FROM languagegroups ORDER BY grpno");
	
	return $self->tt_process("splash.tt", $splash_info);
}

sub elink : Runmode {
	my $self = shift;
	my @etyma;
	for my $t ($self->query->param('t')) { # array context, so param returns the whole list!
		next unless $t =~ /^\d+$/;
		my %e;
		@e{qw/plg pform pgloss/} = $self->dbh->selectrow_array("SELECT languagegroups.plg, protoform, protogloss FROM etyma LEFT JOIN languagegroups USING (grpid) WHERE tag=? AND status != 'DELETE'", undef, $t);
		next unless $e{pform};
		$e{tag} = $t;
		$e{pform} =~ s/⪤ +/⪤ */g;
		$e{pform} =~ s/OR +/OR */g;
		$e{pform} =~ s/~ +/~ */g;
		$e{pform} =~ s/ = +/ = */g;
		$e{pform} = '*' . $e{pform};
		$e{mesoroots} = $self->dbh->selectall_arrayref("SELECT form,gloss,plg FROM mesoroots LEFT JOIN languagegroups USING (grpid) WHERE tag=$t", {Slice=>{}});
		push @etyma, \%e;
	}
	return "Error: no valid tag numbers!" unless @etyma;
	return $self->tt_process("tt/et_info.tt", {etyma=>\@etyma});
}

sub source : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	return $self->all_sources unless $srcabbr;
	
	my ($author, $year, $title, $imprint)
		= $self->dbh->selectrow_array("SELECT author, year, title, imprint FROM srcbib WHERE srcabbr=?", undef, $srcabbr);
	if (!defined($author)) {
		$self->header_add(-status => 400);
		return "Error: No source '$srcabbr' found";
	}

	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, grpid, grpno, grp, COUNT(lexicon.rn), lgid AS num_recs FROM languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid) WHERE srcabbr=? AND lgcode != 0 GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $srcabbr);

	require STEDT::RootCanal::Notes;
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid)"
			. "WHERE spec='S' AND id=? $internal_note_search ORDER BY ord", undef, $srcabbr)}) {
		my $xml = $_->[3];
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>STEDT::RootCanal::Notes::xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>STEDT::RootCanal::Notes::xml2markup($xml), num_lines=>STEDT::RootCanal::Notes::guess_num_lines($xml),
			uid=>$_->[5], username=>$_->[6]
		};
	}


	return $self->tt_process("source.tt", {
		author=>$author, year=>$year, doc_title=>$title, imprint=>$imprint,
		lgs  => $lg_list, srcabbr => $srcabbr, notes => \@notes, footnotes => \@footnotes
	});
}

sub all_sources {
	my $self = shift;
	my $a = $self->dbh->selectall_arrayref("SELECT srcabbr, COUNT(DISTINCT languagenames.lgid) AS num_lgs,
		COUNT(lexicon.rn) AS num_recs, citation, author, year, title, imprint
		FROM srcbib LEFT JOIN languagenames USING (srcabbr) LEFT JOIN lexicon USING (lgid)
		GROUP BY srcabbr
		HAVING num_recs > 0
		ORDER BY citation", {Slice=>{}});
	return $self->tt_process("tt/all_sources.tt", { sources=>$a });
}

sub group : Runmode {
	my $self = shift;
	my $grpid = $self->param('id');
	my $lgid = $self->param('lgid');
	my ($grpno, $grpname) = $self->dbh->selectrow_array(
		"SELECT grpno, grp FROM languagegroups WHERE grpid=?", undef, $grpid);
	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, srcabbr, citation, lgid, COUNT(lexicon.rn) AS num_recs FROM languagenames LEFT JOIN lexicon USING (lgid) LEFT JOIN srcbib USING (srcabbr) WHERE grpid=? AND lgcode != 0 GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $grpid);

	# do a linear search for the index of the record we're interested in
	my $i;
	if ($lgid) {
		my $max = $#$lg_list; # set this here, or else get stuck in an infinite loop if there's no matching record!
		$i = 0;
		$i++ until $lg_list->[$i][5] == $lgid || $i > $max;
		undef $i if $i > $max;
	}
	return $self->tt_process('groups.tt', {
		lg_index => $i,
		lgs=>$lg_list,
		grpid=>$grpid,
		grpno=>$grpno,
		grpname=>$grpname,
		grps => $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp FROM languagegroups ORDER BY grpno")
	});
}


# this subroutine was meant to take a *single* query string
# from a uni-search field (a la google)
# and parse it into search terms in an "intelligent" way.
# now that we've added a separate search box for each field,
# this subroutine should be rethought/split into multiple subs.
sub searchresults_from_querystring {
	my ($self, $f, $s, $tbl, $lg, $lggrp, $lgcode) = @_;
	my $t = $self->load_table_module($tbl);
	my $query = $self->query->new(''); # for some reason faster than saying "new CGI"? disk was thrashing.
	
	# collapse all spaces around commas and ampersands so that boolean
	# search items remain single terms after being split by spaces below.
	# this is provided as a convenience to the searcher, and is in no way
	# meant to imply that users should attempt to do boolean searches
	# across fields (e.g. dog & *kwi will now be interpreted as an AND search
	# in the lexicon.gloss field).
	$s =~ s/\s*([,\&])\s*/$1/g;	# gloss field
	$f =~ s/\s*([,\&])\s*/$1/g;	# form field

	$f =~ s/^\*//g;			# strip initial asterisk from form field, in case anyone tries it

	# figure out the table and the search terms
	# and make sure there's a (unicode) letter in there somewhere
	if ($tbl eq 'etyma') {
		for my $token (split / /, $s) {
			if ($token =~ /\p{Letter}/) {
				$query->param('etyma.protogloss' => $token);
				# print STDERR "Etyma protogloss is $token\n";	# debugging
			}
		}
		for my $token (split / /, $f) {		# allow user to enter proto-form OR tag num in form field
			if ($token =~ /\p{Letter}/) {
				# $token =~ s/^\*//;
				$query->param('etyma.protoform' => $token);
				# print STDERR "Etyma protoform is $token\n";	# debugging
			}
			elsif ($token =~ /^\d+$/) {
				$query->param('etyma.tag' => $token);
			}
		}	
		if (!$s && !$f) {
			$query->param('etyma.tag' => (300,1606)[int(rand 2)]); # which came first, the chicken or the egg?
		} elsif (!$query->param) {
			$query->param('etyma.tag' => 2436);
		}
	} elsif ($tbl eq 'lexicon') {
		$query->param('languagenames.language' => $lg) if $lg =~ /\p{Letter}/;
		
		# languagegroups param must match start with X or a digit and not go past 4 levels (first level is obligatory)
		$query->param('languagegroups.grp' => $lggrp) if $lggrp =~ /^[\dX](\.\d((\.\d)(\.\d)?)?)?$/;
		
		# language code must be an integer
		if (defined($lgcode)) {		# include this test for now, since there's no js code yet to pass lgcode param via ajax
			$query->param('languagenames.lgcode' => $lgcode) if $lgcode =~ /^\d+$/;
		}

		for my $token (split / /, $f) {		# allow user to query reflex or analysis in form field
			if ($token =~ /^\d+$/) {
				$query->param('analysis' => $token);
			}
			elsif ($token =~ /\p{Letter}/) {
				$query->param('lexicon.reflex' => $token);
				# print STDERR "Lexicon reflex is $token\n";	# debugging
			}
		}
		for my $token (split / /, $s) {
			if ($token =~ /\p{Letter}/) {
				$query->param('lexicon.gloss' => $token);
				# print STDERR "Lexicon gloss is $token\n";	# debugging
			}
		}
		if (!$s && !$lg && $lggrp eq '' && !$f) {
#			$query->param('analysis'=>1764);
			$query->param('lexicon.rn'=>344986);
		} elsif (!$query->param) {
			$query->param('analysis'=>5035);
		}
	}

	# only show public etyma 
	if ($tbl eq 'etyma' && !$self->has_privs(1)) {
		$query->param('etyma.public' => 1);
	}

	return $t->search($query);
}

# this runs when the user submits a search from the splash page
sub combo : Runmode {
	my $self = shift;
	my $q = $self->query;
	my $f = decode_utf8($q->param('f')) || '';	# form (i.e. lemma) parameter
	# print STDERR "COMBO: Form param is $f\n";	# debugging
	my $s = decode_utf8($q->param('t')) || '';
	my $lg = decode_utf8($q->param('lg')) || '';
	my $lg_auto = decode_utf8($q->param('as_values_lg-auto')) || '';
	$lg .= ',' . $lg_auto; $lg =~ s/,+/,/g; $lg =~ s/^,//; # consolidate $lg_auto into $lg and get rid of extra commas
	my $lggrp = decode_utf8($q->param('lggrp'));
	$lggrp = '' unless defined($lggrp);
	my $lgcode = decode_utf8($q->param('lgcode')) || '';	# note that lgcode=0 functions as if the param is blank
	# print STDERR "COMBO: Language group param is $lggrp\n";	# debugging
	my $result;

	if ($f || $s || $lg || $lggrp ne '' || $lgcode || !$q->param) {
		if ($ENV{HTTP_REFERER} && ($f || $s || $lg || $lggrp ne '')) {
			$self->dbh->do("INSERT querylog VALUES (?,?,?,?,?,?,NOW())", undef,
				'simple', $f, $s, $lg, $lggrp, $ENV{REMOTE_ADDR});	# record search in query log (put table name, form, gloss, lg, lggroup, ip in separate fields)
		}
		$result->{etyma} = $self->searchresults_from_querystring($f, $s, 'etyma');
		$result->{lexicon} = $self->searchresults_from_querystring($f, $s, 'lexicon', $lg, $lggrp, $lgcode);
	} else {
		$result->{etyma} = $self->load_table_module('etyma')->search($q);
		$result->{lexicon} = $self->load_table_module('lexicon')->search($q);
	}

	# generate the list of language groups for the dropdown box:
	$result->{grps} = $self->dbh->selectall_arrayref("SELECT grpno, grp FROM languagegroups ORDER BY grpno");

	return $self->tt_process("index.tt", $result);
}

# this runs when the user submits a search in either the lexicon or etyma section of the simple search interface
sub ajax : Runmode {
	my $self = shift;
	my $s = decode_utf8($self->query->param('s'));
	my $f = decode_utf8($self->query->param('f'));		# form (i.e. lemma) paramter
	# print STDERR "AJAX: Form param is $f\n";	# debugging
	my $lg = decode_utf8($self->query->param('lg'));
	my $lg_auto = decode_utf8($self->query->param('as_values_lg-auto')) || '';
	$lg .= ',' . $lg_auto; $lg =~ s/,+/,/g; $lg =~ s/^,//;
	my $lggrp = decode_utf8($self->query->param('lggrp'));
	$lggrp = '' unless defined($lggrp);
	my $tbl = $self->query->param('tbl');
	my $lgcode = decode_utf8($self->query->param('lgcode'));
	my $result; # hash ref for the results

	$self->dbh->do("INSERT querylog VALUES (?,?,?,?,?,?,NOW())", undef,
		$tbl, $f, $s, $lg, $lggrp, $ENV{REMOTE_ADDR}) if $s || $lg || $lggrp ne '' || $f;	# record search in query log (put table name, form, gloss, lg, lggroup, ip in separate fields)

	if (defined($s) || defined($f)) {
		if ($tbl eq 'lexicon' || $tbl eq 'etyma') {
			$result = $self->searchresults_from_querystring($f, $s, $tbl, $lg, $lggrp, $lgcode);
		} else {
			die "bad table name!";
		}
	} else { # just pass the query on
		my $t = $self->load_table_module($tbl);
		$result = $t->search($self->query);
	}

	$self->header_add('-type' => 'application/json');
	require JSON;
	return JSON::to_json($result);
}

1;
