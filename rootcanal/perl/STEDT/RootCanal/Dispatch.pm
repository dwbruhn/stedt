package STEDT::RootCanal::Dispatch;
use base 'CGI::Application::Dispatch';

sub dispatch_args {
	return {
		prefix => 'STEDT::RootCanal',
		table  => [
			''                => { app => 'Search' },
			'logout'          => { app => 'Account', rm => 'logout' },
			'update'     => { app=>'Search', rm => 'update' },
			'search/:tbl'     => { app=>'Search', rm => 'blah' },
			'source/:srcabbr' => { app=>'Search', rm => 'source' },
			'group/:id/:lgid?'=> { app=>'Search', rm => 'group' },
			'notes/:tag'      => { app=>'Search', rm => 'notes_for_tag' },
			':app/:rm'        => { },
			':app'        	  => { },
		],
		error_document => '"Opss... Dispatcher gave HTTP Error #%s',
	};
}

1;

# what happens when sessions expire?
# - it disappears
# - give error when user is de-authed from under them
# - user pref for how long to stay logged in

=head1 NAME

STEDT::RootCanal

=head1 SYNOPSIS

	use STEDT::RootCanal::Dispatch;
	STEDT::RootCanal::Dispatch->dispatch(
		args_to_new => {
			PARAMS => {
				cfg_file => '/home/username/stuff/rootcanal.conf'
			}
		}
	);

=head1 INSTALLATION

On the web server, put this with your other custom modules
outside the html directory. Then include in the search path using
use lib '../lib'.

=head1 FEATURES

User/privileges authentication.

=head1 DESIGN

Uses CGI::App. Also don't forget the HTML, stylesheets, and scripts.

=head1 AUTHOR

by Dominic Yu

=head1 VERSION

2009.10.14 in progress
2010.01.06 still in progress

=cut
