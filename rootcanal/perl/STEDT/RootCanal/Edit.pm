package STEDT::RootCanal::Edit;
use strict;
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
	
	my $result = $t->search($q, $self->param('userprivs'));
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
	
	my ($id, $result, $err) = $t->add_record($q, $self->param('userprivs'));
	if ($err) {
		$self->header_props(-status => 400);
		return $err;
	}
	
	# now retrieve it and send back some html
	$id =~ s/"/\\"/g;
	$self->header_add('-x-json'=>qq|{"id":"$id"}|);
	return to_json($result);
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
		my $oldval = $t->get_value($field, $id);
		$t->save_value($field, $value, $id);
		$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
			$self->session->param('uid'), $tblname, $field =~ /([^.]+)$/, $id, $oldval || '', $value); # $oldval might be undefined (and interpreted as NULL by mysql)
		return $value;
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
	if ($self->param('userprivs') < 16) {
		$self->header_props(-status => 403);
		return "User not logged in";
	}
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
