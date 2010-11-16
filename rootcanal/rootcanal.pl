#! /usr/bin/perl
# use lib '../lib';
BEGIN { 
        $^W = 1; 
        unshift @INC, "../pm", "../lib"  if -e "../pm";
}
use STEDT::RootCanal::Dispatch;

STEDT::RootCanal::Dispatch->dispatch(
	args_to_new => {
		PARAMS => {
			cfg_file => '/home/stedt-cgi/rootcanal.conf'
		}
	}
);
