package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';

sub main : StartRunmode {
	my $self = shift;
	return $self->tt_process("login.tt") unless $self->param('userprivs') >= 16;
	
	return $self->tt_process("admin.tt");
}

sub changes : Runmode {
	my $self = shift;
	return $self->tt_process("login.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectall_arrayref("SELECT username,`table`,col,id,oldval,newval,time FROM changelog LEFT JOIN users USING (uid) ORDER BY time DESC LIMIT 20");
	return $self->tt_process("changelog.tt", {changes=>$a});
}

sub queries : Runmode {
	my $self = shift;
	return $self->tt_process("login.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,query,ip,time FROM querylog ORDER BY time DESC LIMIT 100");
	return $self->tt_process("querylog.tt", {queries=>$a});
}

sub listpublic : Runmode {
	my $self = shift;
	return $self->tt_process("login.tt") unless $self->param('userprivs') >= 16;

	my $a = $self->dbh->selectcol_arrayref("SELECT tag FROM etyma WHERE public=1");
	return "[" . join(',', @$a) . "]";
}

# process logins
# sub login : Runmode {
# 	my $self = shift;
# 	
# 	my $q = $self->query;
# 	my $u = $q->param('user');
# 	unless ($u) {
# 		return $self->tt_process("login.tt", { blank => 1 });
# 	}
# 	my ($uid, $pwd, $pwd2) =
# 		$self->dbh->selectrow_array("SELECT uid, password, SHA1(?) FROM users WHERE username=?", undef, $q->param('pwd'), $u);
# 	if (defined($uid) && $pwd eq $pwd2) {
# 		# success!
# 
# 		return $self->_login($uid, $u);
# 	}
# 	return $self->login_fail({});
# }



# helper functions

1;
