package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;

sub main : StartRunmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	
	return $self->tt_process("admin.tt");
}

sub changes : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT username,`table`,col,id,oldval,newval,time FROM changelog LEFT JOIN users USING (uid) ORDER BY time DESC LIMIT 500");
	for my $row (@$a) {
		$_ = decode_utf8($_) foreach @$row;
	}
	return $self->tt_process("admin/changelog.tt", {changes=>$a});
}

sub queries : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,query,ip,time FROM querylog ORDER BY time DESC LIMIT 500");
	return $self->tt_process("admin/querylog.tt", {queries=>$a});
}

sub users : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT username,uid,email,privs,COUNT(DISTINCT rn) FROM users LEFT JOIN lx_et_hash USING (uid) GROUP BY uid");
	return $self->tt_process("admin/users.tt", {users=>$a});
}

sub listpublic : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(16)) { return $err; }

	my $a = $self->dbh->selectcol_arrayref("SELECT tag FROM etyma WHERE public=1");
	return "[" . join(',', @$a) . "]";
}


1;
