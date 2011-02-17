package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';

sub main : StartRunmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;
	
	return $self->tt_process("admin.tt");
}

sub changes : Runmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectall_arrayref("SELECT username,`table`,col,id,oldval,newval,time FROM changelog LEFT JOIN users USING (uid) ORDER BY time DESC LIMIT 20");
	return $self->tt_process("admin/changelog.tt", {changes=>$a});
}

sub queries : Runmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,query,ip,time FROM querylog ORDER BY time DESC LIMIT 100");
	return $self->tt_process("admin/querylog.tt", {queries=>$a});
}

sub users : Runmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectall_arrayref("SELECT * FROM users");
	return $self->tt_process("admin/users.tt", {users=>$a});
}

sub listpublic : Runmode {
	my $self = shift;
	return $self->tt_process("admin/https_warning.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectcol_arrayref("SELECT tag FROM etyma WHERE public=1");
	return "[" . join(',', @$a) . "]";
}


1;
