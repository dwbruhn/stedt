package STEDT::RootCanal::Edit;
use strict;
use feature 'switch';
use base 'STEDT::RootCanal::Base';
use Encode;
use CGI;
use JSON;

sub table : StartRunmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;
	my $tbl = $self->param('tbl');
	my $t = $self->load_table_module($tbl);
	my $q = $self->query;
	
	my $result = $t->search($q, $self->param('userprivs'), 1);
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
		my $fakeq = CGI->new('');
		for my $fld ($t->searchable()) {
			# copy in the old, non-empty parameters
			$fakeq->param($fld, $q->param($fld)) if $q->param($fld);
		}
		for my $fld (@{$result->{fields}}) {
			$fakeq->param('sortkey',$fld);
			$sortlinks{$fld} = $fakeq->self_url;
		}
	}

	# pass to tt: searchable fields, results, addable fields, etc.
	return $self->tt_process("admin/edit.tt", {
		t=>$t,
		result => $result,
		manual => $manual_paging, sortlinks => \%sortlinks,
		a => $a, b => $b, pagenum => $pagenum,
		
	});
}


sub add : Runmode {
	my $self = shift;
	if ($self->param('userprivs') < 16) {
		$self->header_props(-status => 403);
		return "User not logged in";
	}

	my $tbl = $self->param('tbl');
	my $t = $self->load_table_module($tbl);
	my $q = $self->query;
	
	# check for valid data
	my $sub = $t->add_check();
	if ($sub && (my $err = $sub->($q))) {
		$self->header_props(-status => 400);
		return $err;
	}
	
	# make list of fields to be populated
	my @fields;
	for my $param ($q->param) {
		push @fields, $param if $t->in_addable($param);
	}

	# add a new record
	my $sth = $self->dbh->prepare("INSERT $tbl ("
		. join(',', @fields)
		. ") VALUES ("
		. join(',', (('?') x @fields))
		. ")");
	eval { $sth->execute(map {$q->param($_)} @fields)	};
	if ($@) {
		$self->header_props(-status => 400);
		return $sth->errstr;
	}

	my $id = $q->param($t->{key})
		|| $self->dbh->selectrow_array("SELECT LAST_INSERT_ID()");
		# only get the last insert id if the key wasn't explicitly set
	for my $field (@fields) {
		my $sub = $t->save_hooks($field);
		$sub->($id, $q->param($field)) if $sub;
	}
	
	# now retrieve it and send back some html
	$self->header_add('-x-json'=>qq|{"id":"$id"}|);
	$q->delete_all();
	$q->param($t->{key},$id);
	my ($query_string) = $t->get_query($q, $self->param('userprivs'));
	my $a = $self->dbh->selectall_arrayref($query_string);
	return to_json($a->[0]);
}


sub update : Runmode {
	my $self = shift;
	my $q = $self->query;

	my ($tblname, $field, $id, $value) = ($q->param('tbl'), $q->param('field'),
		$q->param('id'), decode_utf8($q->param('value')));
	my $t;
	
	if ($self->param('user')
	   && ($self->param('userprivs') > 1) ### need to figure out who can edit what
	   && ($t = $self->load_table_module($tblname))
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

# helper method to do on-the-fly language selection
sub json_lg : Runmode {
	my $self = shift;
	my $srcabbr = $self->param('srcabbr');
	my $a = $self->dbh->selectall_arrayref("SELECT lgid, language FROM languagenames WHERE srcabbr LIKE ? ORDER BY language", undef, $srcabbr);
	my @ids = map {$_->[0]} @$a;
	my @names = map {qq|"$_->[1]"|} @$a;
	$self->header_add('-x-json'=>qq|{"ids":[| . join(',',@ids)
		. qq|],"names":[| . join(',',@names) . "]}");
	return;
}

sub single_record : Runmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;
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
				$self->session->param('uid'), $tbl, $col, $id, $result->[$colname2num{$col}], $updated{$col});
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
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;
	my $tag = $self->param('src');
	my $dst = $self->param('dst');
	my $supertag = $self->param('srcsuper');
	my $newsuper = ($supertag eq $dst) ? $tag : $dst;
	$self->dbh->do("UPDATE etyma SET supertag=? WHERE tag=?", undef, $newsuper, $tag);

	# update successful! now update the "changes" table
	$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
		$self->session->param('uid'), 'etyma', 'supertag', $tag, $supertag, $newsuper);
	return '';
}

1;
