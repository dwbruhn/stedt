package STEDT::RootCanal::Autosuggest;
use strict;
use base 'STEDT::RootCanal::Base';
use JSON;
use Encode;

sub dummy : Startrunmode {
	my $self = shift;
	$self->header_add('-type' => 'application/json');
	return to_json({hi=>5});
}

sub lgs : Runmode {
	my $self = shift;
	my $q = '[[:<:]]' . decode_utf8($self->query->param('q'));
	my $result = $self->dbh->selectall_arrayref("SELECT DISTINCT language AS v FROM languagenames WHERE language RLIKE ?", {Slice=>{}}, $q);
	$self->header_add('-type' => 'application/json');
	return to_json($result);
}

1;
