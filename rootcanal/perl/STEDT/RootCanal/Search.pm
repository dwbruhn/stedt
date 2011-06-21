package STEDT::RootCanal::Search;
use strict;
use base 'STEDT::RootCanal::Base';
use JSON;


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
	return $self->tt_process("index.tt");
}

sub source : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	
	my ($author, $year, $title, $imprint)
		= $self->dbh->selectrow_array("SELECT author, year, title, imprint FROM srcbib WHERE srcabbr=?", undef, $srcabbr);

	my $lg_list = $self->dbh->selectall_arrayref(
		"SELECT silcode, language, lgcode, grpid, grpno, grp, COUNT(lexicon.rn), lgid AS num_recs FROM languagenames NATURAL LEFT JOIN languagegroups LEFT JOIN lexicon USING (lgid) WHERE srcabbr=? AND lgcode != 0 GROUP BY lgid HAVING num_recs > 0 ORDER BY lgcode, language", undef, $srcabbr);

	return $self->tt_process("source.tt", {
		author=>$author, year=>$year, title=>$title, imprint=>$imprint,
		lgs  => $lg_list
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
	my ($self, $s, $tbl) = @_;
	my $t = $self->load_table_module($tbl, 0);
	my $query = $self->query->new; # for some reason faster than saying "new CGI"? disk was thrashing.

	# figure out the table and the search terms
	if ($tbl eq 'etyma') {
		for my $token (split / /, $s) {
			if ($token =~ /^\*/) {
				s/^\*//;
				$query->param('etyma.protoform' => $_);
			}
			elsif (/^\d+$/) {
				$query->param('etyma.tag' => $token);
			}
			else {
				$query->param('etyma.protogloss' => $token);
			}
		}
		if ($s eq '') {
			$query->param('etyma.chapter'=>'9.' . (int(rand 9) + 1));
		}
	} elsif ($tbl eq 'lexicon') {
		for my $token (split / /, $s) {
			if ($token =~ /^\d+$/) {
				$query->param('analysis' => $token);
			}
			else {
				$query->param('lexicon.gloss' => $token);
			}
		}
		if ($s eq '') {
			$query->param('analysis'=>1764);
		}
	}

	# only show public etyma 
	if ($tbl eq 'etyma' && $self->param('userprivs') < 2) {
		$query->param('etyma.public' => 1);
	}

	return $t->search($query, $self->param('userprivs'));
}

sub blah : Runmode { # this sub wants a nicer name
	my $self = shift;
	my $s = $self->query->param('s');
	my $tbl = $self->param('tbl');
	my $result; # hash ref for the results

	$self->dbh->do("INSERT querylog VALUES (?,?,?,NOW())", undef,
		$tbl, $s, $ENV{REMOTE_ADDR}) if $s;

	if (defined($s)) {
		if ($tbl eq 'simple') {
			$result->{table} = 'simple';
			$result->{etyma} = $self->searchresults_from_querystring($s, 'etyma');
			$result->{lexicon} = $self->searchresults_from_querystring($s, 'lexicon');
		} elsif ($tbl eq 'lexicon' || $tbl eq 'etyma') {
			$result = $self->searchresults_from_querystring($s, $tbl);
		} else {
			die "bad table name!";
		}
	} else { # just pass the query on
		my $t = $self->load_table_module($tbl, 0);
		$result = $t->search($self->query, $self->param('userprivs'));
	}

	$self->header_add('-type' => 'application/json');
	return to_json($result);
}

1;
