package STEDT::RootCanal::Search;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;

sub extractions : Runmode {
	my $self = shift;
	# find all etyma with extraction < 2
	# there should be an extraction table with name of the extraction
	# and possibly the name of the pdf file
	# there should be a pdf directory with pdf's
	
	# pass to extractions.tt:
	# list of extractions
	
	# generate a list, with a pdf link too.
	# each extraction will be
	# - a set of (semantically based) chapters
	# - one chapter
	# - a set of misc. forms, phonologically based.
	
	# the phonologically based sets are going to be harder to organize
	# because we don't want to duplicate sequence numbers
	
	# eventually this page should become moot (?) because 
	# you'll be able to get to it from a "table of contents" page.
	# or rather, this is intended as a chronological listing of published forms,
	# rather than a semantically based one.
	return $self->tt_process("extractions.tt");
}


sub splash : StartRunmode {
	my $self = shift;
	return $self->tt_process("splash.tt");
}

sub elink : Runmode {
	my $self = shift;
	my @etyma;
	for my $t ($self->query->param('t')) { # array context, so param returns the whole list!
		next unless $t =~ /^\d+$/;
		my %e;
		push @etyma, \%e;
		$e{tag} = $t;
		@e{qw/plg pform pgloss/} = $self->dbh->selectrow_array("SELECT plg, protoform, protogloss FROM etyma WHERE tag=?", undef, $t);
		$e{pform} =~ s/⪤ +/⪤ */g;
		$e{pform} =~ s/OR +/OR */g;
		$e{pform} =~ s/~ +/~ */g;
		$e{pform} =~ s/ = +/ = */g;
		$e{pform} = '*' . $e{pform};
	}
	return "Error: no valid tag numbers!" unless @etyma;
	return $self->tt_process("tt/et_info.tt", {etyma=>\@etyma});
}

sub source : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	
	my ($author, $year, $title, $imprint)
		= $self->dbh->selectrow_array("SELECT author, year, title, imprint FROM srcbib WHERE srcabbr=?", undef, $srcabbr);

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

sub group : Runmode {
	my $self = shift;
	my $grpid = $self->param('id');
	my $lgid = $self->param('lgid');
	my ($grpno, $grpname) = $self->dbh->selectrow_array(
		"SELECT grpno, grp FROM languagegroups WHERE grpid=?", undef, $grpid);
	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, srcabbr, lgid, COUNT(lexicon.rn) AS num_recs FROM languagenames LEFT JOIN lexicon USING (lgid) WHERE grpid=? AND lgcode != 0 GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $grpid);

	# do a linear search for the index of the record we're interested in
	my $i;
	if ($lgid) {
		my $max = $#$lg_list; # set this here, or else get stuck in an infinite loop if there's no matching record!
		$i = 0;
		$i++ until $lg_list->[$i][4] == $lgid || $i > $max;
		undef $i if $i > $max;
	}
	return $self->tt_process('groups.tt', {
		lg_index => $i,
		lgs=>$lg_list,
		grpid=>$grpid,
		grpno=>$grpno,
		grpname=>$grpname,
		grps => $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp FROM languagegroups ORDER BY ord, grpno")
	});
}

sub searchresults_from_querystring {
	my ($self, $s, $tbl, $lg, $lggrp) = @_;
	my $t = $self->load_table_module($tbl);
	my $query = $self->query->new(''); # for some reason faster than saying "new CGI"? disk was thrashing.

	# figure out the table and the search terms
	# and make sure there's a (unicode) letter in there somewhere
	if ($tbl eq 'etyma') {
		for my $token (split / /, $s) {
			if ($token =~ /^\*\p{Letter}/) {
				$token =~ s/^\*//;
				$query->param('etyma.protoform' => $token);
			}
			elsif ($token =~ /^\d+$/) {
				$query->param('etyma.tag' => $token);
			}
			elsif ($token =~ /\p{Letter}/) {
				$query->param('etyma.protogloss' => $token);
			}
		}
		if (!$s) {
			$query->param('etyma.chapter'=>'9.' . (int(rand 9) + 1));
		} elsif (!$query->param) {
			$query->param('etyma.tag' => 2436);
		}
	} elsif ($tbl eq 'lexicon') {
		$query->param('languagenames.language' => $lg) if $lg =~ /\p{Letter}/;
		
		# languagegroups param must match start with X or a digit and not go past 4 levels (first two levels are obligatory)
		$query->param('languagegroups.grp' => $lggrp) if $lggrp =~ /^[\dX]\.\d((\.\d)(\.\d)?)?$/;
		# print STDERR "Language group param is $lggrp\n";	# debugging

		for my $token (split / /, $s) {
			if ($token =~ /^\d+$/) {
				$query->param('analysis' => $token);
			}
			elsif ($token =~ /\p{Letter}/) {
				$query->param('lexicon.gloss' => $token);
			}
		}
		if (!$s && !$lg && !$lggrp) {
			$query->param('analysis'=>1764);
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

sub combo : Runmode {
	my $self = shift;
	my $q = $self->query;
	my $s = decode_utf8($q->param('t')) || '';
	my $lg = decode_utf8($q->param('lg')) || '';
	my $lggrp = decode_utf8($q->param('lggrp')) || '';
	my $result;

	if ($s || $lg || $lggrp || !$q->param) {
		if ($ENV{HTTP_REFERER} && ($s || $lg || $lggrp)) {
			$self->dbh->do("INSERT querylog VALUES (?,?,?,NOW())", undef,
				'simple', $lg ? "$s {$lg}" : $s, $ENV{REMOTE_ADDR});	# record search in query log (needs to be cleaned up someday)
		}
		$result->{etyma} = $self->searchresults_from_querystring($s, 'etyma');
		$result->{lexicon} = $self->searchresults_from_querystring($s, 'lexicon', $lg, $lggrp);
	} else {
		$result->{etyma} = $self->load_table_module('etyma')->search($q);
		$result->{lexicon} = $self->load_table_module('lexicon')->search($q);
	}
	return $self->tt_process("index.tt", $result);
}

sub ajax : Runmode {
	my $self = shift;
	my $s = decode_utf8($self->query->param('s'));
	my $lg = decode_utf8($self->query->param('lg'));
	my $lggrp = decode_utf8($self->query->param('lggrp'));
	# print STDERR "AJAX: Language group param is $lggrp\n";	# debugging
	my $tbl = $self->query->param('tbl');
	my $result; # hash ref for the results

	$self->dbh->do("INSERT querylog VALUES (?,?,?,NOW())", undef,
		$tbl, $lg ? "$s {$lg}" : $s, $ENV{REMOTE_ADDR}) if $s || $lg;

	if (defined($s)) {
		if ($tbl eq 'lexicon' || $tbl eq 'etyma') {
			$result = $self->searchresults_from_querystring($s, $tbl, $lg, $lggrp);
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
