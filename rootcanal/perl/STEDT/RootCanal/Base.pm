package STEDT::RootCanal::Base;
use strict;
use base 'CGI::Application';
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Session;
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::DBH qw/dbh_config dbh/;
use CGI::Application::Plugin::ValidateRM;
use CGI::Application::Plugin::ConfigAuto qw/cfg/;

# This is the base class for different STEDT::RootCanal modules.
# It handles
# (1) connecting to the database
# (2) checking if the user has/hasn't logged in.

# In addition to modules used directly in this file
# (Session, AutoRunmode, ConfigAuto, DBH),
# we also load various perl modules (TT, ValidateRM)
# which our subclasses will use.

# If the user has authenticated, we retrieve the user id and save it to
# $self->param('uid'), and the username to $self->param('user'),
# so that our subclasses/template files can read them easily.

sub cgiapp_init {
	my $self = shift;
	
	# read our login info from the config file
	# then set up a database connection
	$self->dbh_config("dbi:mysql:stedt", $self->cfg('login'), $self->cfg('pass'),
		{RaiseError => 1,AutoCommit => 1});

	# set the database connection to use unicode, or you'll be sorry
	$self->dbh->do("SET NAMES 'utf8';");
	
	# this tells CGI::App to set the HTML headers correctly
	$self->header_props(-charset => 'UTF-8');

	# a rough test to see if we're running over SSL
	# if we are, send a different session id over the secure connection
	my $secure = $self->query->cookie('stsec') ? 1 : 0;

	# set up the session, telling it to use the above database connection
	# to store the session info.
	$self->session_config(
		CGI_SESSION_OPTIONS => ["driver:mysql",
								$self->query,
								{ Handle  => $self->dbh },
								$secure ? { name => 'CGISECID' } : undef],
		COOKIE_PARAMS => {	-name=> ($secure ? 'CGISECID' : CGI::Session->name),
							-secure => $secure,
							-httponly => 1 }
	);
}

# check for authenticated user, every time
sub cgiapp_prerun {
	my $self = shift;
	my $uid = $self->session->param('uid');
	if (defined $uid) {
		my ($user, $privs) =
			$self->dbh->selectrow_array("SELECT username, privs FROM users WHERE uid=?", undef, $uid);
		
		# save username for access by the template
		$self->param(user => $user);
		$self->param(userprivs => $privs);
	}
	# set/reset expiration
	$self->session->expire("1y");
	# additional cookie to test for a secure connection on the next HTTP request
	$self->header_add(-cookie=>
		[$self->query->cookie(-name=>'stsec',-value=>1,-secure=>1)]);
}

# using C::A::P::AutoRunmode, we set this to be called in the event of an error
sub unable_to_comply : ErrorRunmode {
	my ($self, $err) = @_;
	$self->header_props(-status => 500); # server error
	return $err; # just the text, ma'am (it might show up in a javascript alert)
}

1;
