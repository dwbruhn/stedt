package STEDT::RootCanal::Search;
use strict;
use feature 'switch';
use base 'STEDT::RootCanal::Base';
use JSON;
use Encode;
use utf8;

# helper function to load the relevant module
sub load_table_module {
	my ($tbl, $dbh) = @_;
	$tbl =~ /\W/ and die "table name contained illegal characters!"; # prevent sneaky injection attacks
	$tbl =~ s/^(.)/\u$1/; # uppercase the first char
	my $tbl_class = "STEDT::Table::$tbl";
	eval "require $tbl_class" or die $@;
	return $tbl_class->new($dbh);
}

sub splash : StartRunmode {
	my $self = shift;
	return $self->tt_process("index.tt");
}

sub update : Runmode {
	my $self = shift;
	my $q = $self->query;

	my ($tblname, $field, $id, $value) = ($q->param('tbl'), $q->param('field'), $q->param('id'), $q->param('value'));
	my $t;
	
	if ($self->param('user')
	   && ($self->param('userprivs') > 1) ### need to figure out who can edit what
	   && ($t = load_table_module($tblname, $self->dbh))
	   && $t->in_editable($field)) {
		my $oldval = $self->dbh->selectrow_array("SELECT $field FROM $tblname WHERE $t->{key}=?", undef, $id);
		$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
			$self->session->param('uid'), $tblname, $field =~ /([^.]+)$/, $id, $oldval, $value);
		$t->save_value($field, $value, $id);
		return $q->escapeHTML($value);
	} else {
		$self->header_props(-status => 403); # Forbidden
		return "User not logged in" unless $self->param('user');
		return "Field $field not editable";
	}
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
		grps => $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp FROM languagegroups")
	});
}


sub _tag2info {
	my ($t, $s, $dbh) = @_;
	my @a = $dbh->selectrow_array("SELECT etyma.protoform,etyma.protogloss FROM etyma WHERE tag=?", undef, $t);
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my ($form, $gloss) = map {decode_utf8($_)} @a;
	$form =~ s/-/‑/g; # non-breaking hyphens
	$form =~ s/^/*/;
	$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
	$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
	if ($s) {			# alternative gloss, add it in
		$s = "$form $s";
	} else {
		$s = "$form $gloss"; # put protogloss if no alt given
	}
	return $s;
}

sub _nonbreak_hyphens {
	my $s = $_[0];
	$s =~ s/-/‑/g;
	return $s;
}

my @italicize_abbrevs =
qw|GSR GSTC STC HPTB TSR AHD VSTB TBT HCT LTBA BSOAS CSDPN TIL OED|;

sub xml2html {
	my @footnotes;
	my $i = 1;
	my $dbh = $_[1];
	local $_ = $_[0];
	s|<par>|<p>|g;
	s|</par>|</p>|g;
	s|<emph>|<i>|g;
	s|</emph>|</i>|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"<b>*" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2,$dbh)|ge;
	s|<footnote>(.*?)</footnote>|push @footnotes, $1; "<sup>" . $i++ . "</sup>"|ge;
	s|<hanform>(.*?)</hanform>|$1|g;
	s|<latinform>(.*?)</latinform>|"<b>" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<plainlatinform>(.*?)</plainlatinform>|$1|g;

	s/(\S)&apos;/$1’/g; # smart quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s|\b($abbrev)\b|<i>$1</i>|g;
	}
	### specify STEDTU here?

	s/&lt;-+&gt;/⟷/g; # convert arrows
	s/< /< /g; # no-break space after "comes from" sign
	
	$i = 1;
	for my $f (@footnotes) { $_ .= '<p class="footnote">' . $i++ . ". $f</p>" }
	return $_;
}


sub notes_for_tag : Runmode {
	my $self = shift;
	my $tag = $self->param('tag');
	
	my $notes = $self->dbh->selectall_arrayref("SELECT xmlnote FROM notes WHERE tag=?", undef, $tag);
	my @notes;
	for (@$notes) {
		 my $xml = decode_utf8($_->[0]);
		 push @notes, xml2html($xml, $self->dbh);
	}
	return join '', @notes;
}

sub searchresults_from_querystring {
	my ($self, $s, $tbl) = @_;
	my $t = load_table_module($tbl, $self->dbh);
	my $query = new CGI;

	# figure out the table and the search terms
	if ($tbl eq 'etyma') {
		for my $token (split / /, $s) { given ($token) {
			when (/^\*/) {
				s/^\*//;
				$query->param('etyma.protoform' => $_);
			}
			when (/^\d+$/) {
				$query->param('etyma.tag' => $token);
			}
			default {
				$query->param('etyma.protogloss' => $token);
			}
		}}
		if ($s eq '') {
			$query->param('etyma.chapter'=>'9.' . (int(rand 9) + 1));
		}
	} elsif ($tbl eq 'lexicon') {
		for my $token (split / /, $s) { given ($token) {
			when (/^\d+$/) {
				$query->param('lexicon.analysis' => $token);
			}
			default {
				$query->param('lexicon.gloss' => $token);
			}
		}}
		if ($s eq '') {
			$query->param('lexicon.analysis'=>1764);
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
		my $t = load_table_module($tbl, $self->dbh);
		$result = $t->search($self->query, $self->param('userprivs'));
	}

	$self->header_add('-type' => 'application/json');
	return to_json($result);
}

1;
