package STEDT::RootCanal::Subgroups;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use Encode;

sub view: StartRunmode {
	my $self = shift;
	$self->require_privs(1);
	my $a = $self->dbh->selectall_arrayref("SELECT grpid, grpno, grp, COUNT(lgid) AS num_lgs, plg, genetic
		FROM languagegroups LEFT JOIN languagenames USING (grpid)
		GROUP BY grpid
		ORDER BY grpno");
	for my $row (@$a) {
		my $str = $row->[1];
		$str =~ s/\.0//g;
		my $indent_level = $str =~ tr/.//;
		if ($indent_level) {
			$row->[1] = "     $row->[1]" for (1..$indent_level);
			$row->[2] = "     $row->[2]" for (1..$indent_level);
		}
	}

	# pass to tt: searchable fields, results, addable fields, etc.
	return $self->tt_process("admin/subgroups.tt", {
		result => $a
	});
}

sub update : RunMode {
	my $self = shift;
	$self->require_privs(8);
	my $q = $self->query;
	my $fld = $q->param('field');
	die "can't edit field $fld\n" unless $fld eq 'grp' || $fld eq 'plg' || $fld eq 'genetic';

	my $id = $q->param('id');
	$id =~ s/^.*?_//;

	my $s = decode_utf8($q->param('value'));
	my $indent = '';
	($indent) = $s =~ /^(\s+)/ if $fld eq 'grp';
	$s =~ s/^(\s+)//; # trim spaces, non-breaking spaces, etc.
	$s =~ s/\s+$//;

	$self->dbh->do("UPDATE languagegroups SET `$fld`=? WHERE grpid=?", undef, $s, $id);
	return $indent . $s;
}

1;
