package STEDT::RootCanal::Edit;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use utf8;

sub table : StartRunmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	my $tbl = $self->param('tbl');
	my $t = $self->load_table_module($tbl);
	my $q = $self->query;
	
	my $result = $t->search($q);
	# it doesn't seem to be too inefficient to pull out all the results
	# and then count them and/or send partial results to the browser (for paging)
	# The alternative is to do a COUNT * first, which mysql should be optimized for,
	# but we can do that if performance becomes an issue.
	
	# manual paging for large results
	my $numrows = scalar @{$result->{data}};
	my ($manual_paging, $a, $b) = (0, 1, $numrows);
	my $SearchLimit = 500;
	my $pagenum;
	my %sortlinks;

	if ($numrows > $SearchLimit*2) {
		$manual_paging = 1;
		my $n = $q->param('pagenum') + ($q->param('next') ? 1 : ($q->param('prev') ? -1 : 0));
		$a = $n*$SearchLimit + 1;
		$b = $a + $SearchLimit - 1;
		$b = $numrows if $numrows < $b;
		$pagenum = $n;
		
		# make links for manual sorting
		my $fakeq = $q->new();
		for my $fld ($t->searchable()) {
			# copy in the old, non-empty parameters
			$fakeq->param($fld, $q->param($fld)) if $q->param($fld);
		}
		for my $fld (@{$result->{fields}}) {
			$fakeq->param('sortkey',$fld);
			$sortlinks{$fld} = $fakeq->self_url;
		}
	}

	# special case: include footnotes for lexicon table
	my @footnotes;
	my $footnote_index = 1;
	if ($tbl eq 'lexicon') {
		require STEDT::RootCanal::Notes;
		STEDT::RootCanal::Notes::collect_lex_notes($self, $result->{data}, $self->has_privs(1), \@footnotes, \$footnote_index);
	}

	# pass to tt: searchable fields, results, addable fields, etc.
	return $self->tt_process("admin/edit.tt", {
		t=>$t,
		result => $result,
		manual => $manual_paging, sortlinks => \%sortlinks,
		a => $a, b => $b, pagenum => $pagenum,
		footnotes => (($tbl eq 'lexicon' && $self->has_privs(1)) ? \@footnotes : undef)
	});
}


sub add : Runmode {
	my $self = shift;
	my $tblname = $self->param('tbl');
	my $privs = $tblname eq 'etyma' ? 1 : 16;
	# taggers can only add etyma, not lexicon/languagename/etc. records
	if (my $err = $self->require_privs($privs)) { return $err; }

	my $t = $self->load_table_module($tblname);
	my $q = $self->query;
	
	my ($id, $result, $err) = $t->add_record($q);
	if ($err) {
		$self->header_add(-status => 400);
		return $err;
	}
	$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
		       $self->param('uid'), $tblname, '+added', $id, '', '');
	
	# now retrieve it and send back some html
	$id =~ s/"/\\"/g;
	$self->header_add('-x-json'=>qq|{"id":"$id"}|);
	require JSON;
	return JSON::to_json($result);
}


# check to see if the only change involves adding or deleting delimiters. if so, it
# directly modifies the second argument by replacing added spaces with a STEDT delim,
# and also strips out surrounding whitespace.
sub delims_only {
	my @a = split '', $_[0]; # split our strings into chars
	my @b = split '', ($_[1] =~ /(\S.*\S)/)[0]; # ignore starting/trailing whitespace ((...)[0] forces list context)
	my $delims_only = 1;
	my $i = 0;
	my $j = 0;
	
	while ($delims_only && $i < @a && $j < @b) { # while the strings match and we haven't reached the end yet...
		if ($a[$i] ne $b[$j]) { # do nothing if they match at the current indexes
			unless (
				($i+1 < @a && $a[$i+1] eq $b[$j] && $a[$i] =~ /[◦\|]/ && $i++) ||
					# char was deleted and it was '◦' or '|'
				($j+1 < @b && $b[$j+1] eq $a[$i] && ($b[$j] =~ /[◦\|]/ || ($b[$j] eq ' ' && ($b[$j] = '◦'))) && $j++)
					# char was added and it was '◦' or '|',
					# or it was a space, in which case we change it to be '◦', and so yes that's *supposed* to be an assignment operator!
					# Finally, increment the counter if all the other tests pass.
					) {
				$delims_only = 0;
			}
		}
		$i++;
		$j++;
	}
	return 0 if !$delims_only;
	# make sure both strings have been read to the end
	if (($i == @a && $j == @b) ||
		($j == @b && $i+1 == @a && $a[$i] eq '|') ||
		($i == @a && $j+1 == @b && $b[$j] eq '|') # special case: allow add/delete of overriding delim at the end
		) {
		$_[1] = join '', @b;	# modify-in-place
		return 1;
	}
	return 0;
}

sub update : Runmode {
	my $self = shift;
	my $q = $self->query;

	my ($tblname, $field, $id, $value, $fake_uid) = ($q->param('tbl'), $q->param('field'),
		$q->param('id'), decode_utf8($q->param('value')), $q->param('uid2'));
	undef $fake_uid if $fake_uid == $self->param('uid');
	if ($fake_uid && !$self->has_privs(8)) {
		$self->header_add(-status => 403); # Forbidden
		return "You are not allowed to edit other people's tags.";
	}
	my $t;
	
	if ($self->param('user')
	   && ($self->has_privs(1))
	   && ($t = $self->load_table_module($tblname, $fake_uid))
	   && ($t->{field_editable_privs}{$field} & $self->param('userprivs') || $t->in_editable($field))) {
		my $oldval = $t->get_value($field, $id);

		# special case for lexicon form editing by taggers: restrict to delimiters
		if ($tblname eq 'lexicon' && $field eq 'lexicon.reflex') {
			my $delims_only = delims_only($oldval,$value);
			# this has the effect of converting spaces to stedt delimiters if the only things added were delimiters
			
			if ($self->param('userprivs') == 1 && !$delims_only) {
				# this prevents taggers from making modifications to the form field
				# other than adding and removing delimiters
				$self->header_add(-status => 403);
				return "You are only allowed to add delimiters to the form!";
			}
		}

		$t->save_value($field, $value, $id);
		if ($fake_uid) {
			$field = "other_an:$fake_uid";
		}
		$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
			$self->param('uid'), $tblname, $field =~ /([^.]+)$/, $id, $oldval || '', $value); # $oldval might be undefined (and interpreted as NULL by mysql)
		return $value;
	} else {
		$self->header_add(-status => 403); # Forbidden
		return "User not logged in" unless $self->param('user');
		return "Field $field not editable";
	}
}

# helper method to do on-the-fly language selection
sub json_lg : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	my $a = $self->dbh->selectall_arrayref("SELECT lgid, language FROM languagenames WHERE srcabbr LIKE ? ORDER BY language", undef, $srcabbr);
	require JSON;
	return JSON::to_json($a);
}

sub single_record : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(16)) { return $err; }
	my $tbl = $self->param('tbl');
	my $id = $self->param('id');
	my $t = $self->load_table_module($tbl);
	my $q = $self->query;
	
	my $key = $t->{key};
	$key =~ s/^.*\.//;
	my $sth = $self->dbh->prepare("SELECT * FROM $tbl WHERE `" . $key . "`=?");
	$sth->execute($id);
	my $result = $sth->fetchrow_arrayref;
	my $cols = $sth->{NAME};
	
	# if getting an update form, process it
	my $i = 0;
	my %colname2num;
	$colname2num{$_} = $i++ foreach @$cols;
	my %updated;
	for my $col ($q->param) {
		next if $col eq 'rootcanal_btn';
		if ($q->param($col) ne $result->[$colname2num{$col}]) {
			$updated{$col} = $q->param($col);
		}
	}
	if (%updated) {
		my @keys = keys %updated;
		my $update_str = join ', ', map {"`$_`=?"} @keys;
		$self->dbh->do("UPDATE $tbl SET $update_str WHERE `" . $key . "`=?", undef, @updated{@keys}, $id);
		# update successful! now update the "changes" table
		for my $col (@keys) {
			$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
				$self->param('uid'), $tbl, $col, $id, $result->[$colname2num{$col}], $updated{$col});
		}
		$sth->execute($id);
		$result = $sth->fetchrow_arrayref;
	}
	
	return $self->tt_process("admin/single_record.tt", {
		t=>$t, id=>$id,
		result => $result,
		cols => $cols
	});
}

sub makesubroot : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	my $tag = $self->param('src');
	my $dst = $self->param('dst');
	my $supertag = $self->param('srcsuper');
	my $newsuper = ($supertag eq $dst) ? $tag : $dst;
	$self->dbh->do("UPDATE etyma SET supertag=? WHERE tag=?", undef, $newsuper, $tag);

	# update successful! now update the "changes" table
	$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
		$self->param('uid'), 'etyma', 'supertag', $tag, $supertag, $newsuper);
	return '';
}

1;
