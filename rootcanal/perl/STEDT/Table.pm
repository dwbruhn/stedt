package STEDT::Table;
use strict;

# by Dominic Yu
# 2008.04.21, 2009.10.14
# This is a base class to specify the fields, attributes, and behavior
# of a particular table in the database.
# That is, subclasses specify e.g. which fields to use in queries,
# and this module uses that info to actually do the searches.
# See Etyma.pm for a subclass example.

# for AUTOLOAD, we have three kinds of data to access:
# scalars, hashes, and sets
our %ivars = map {$_,1} qw(
	table
	key
	query_from
	order_by
	also_group_by
	select_distinct
	search_limit
	debug
	allow_delete
	
	footer_extra
	
	delete_hook
	add_check
);

our %hash_vars = map {$_,1} qw(
	field_visible_privs
	sizes
	search_form_items
	
	update_form_items
	print_form_items
	add_form_items
	save_hooks
);

our %set_vars = map {$_,1} qw(
	calculated_fields
	searchable
	editable
	addable
	
	search_by_disjunction
);

my %preset_wheres = (
	'int' => \&where_int,
	'word' => \&where_word,
	'beginword' => \&where_beginword,
	'rlike' => \&where_rlike,
);

# METHODS

sub new {
	my $class = shift;
	my $self = {};
	$self->{dbh} = shift;
	$self->{table} = shift; # THIS MUST BE FILLED IN BY A SUBCLASS
	
	my $key = shift;
	$self->{key} = $key;
	$self->{wheres}{$key} = \&where_int;
	
	$self->{search_limit} = 1000;
	return bless $self, $class;
}

# the list of fields is *ordered*, and this order is used by other
# subroutines (see e.g. AUTOLOAD).
sub fields {
	my $self = shift;
	if (@_) {
		my @a = @_;
		my @full_fields = @a;	# save the full fields for queries
		foreach (@a) {					# for all other purposes, use the "AS" aliases, if there is one
			if (/ AS /) {
				$_ =~ s/^.+ AS //;
				$self->calculated_fields($_);
					# because of an idiosyncrasy in our AUTOLOAD method,
					# this actually replaces the old list, but we never access
					# the entire list, just the hash, which gets a new entry when we call this, so it's OK
			}
		}
		$self->{fields} = [@a];
		%{$self->{is_field}} = map {$_,1} @a;	# for efficient lookup later
		%{$self->{field_visible_privs}} = map {$_,1} @a;	# all visible by default
		@{$self->{full_fields}}{@a} = @full_fields;
		die "key not in fields list!" unless $self->{is_field}{$self->{key}};
	} else {
		return @{$self->{fields}}; # return a list
	}
}

sub fields_for_priv {
	my ($self, $priv, $fullnames) = @_;
	$priv = 1 if !$priv;
	my @result;
	
	for (@{$self->{fields}}) {
		push @result, ($fullnames ? $self->{full_fields}{$_} : $_)
			if $priv >= $self->{field_visible_privs}{$_};
	}
	return @result;
}

sub AUTOLOAD {
	return if our $AUTOLOAD =~ /::DESTROY$/;
	my $self = shift;
	my $name = $AUTOLOAD;
	$name =~ s/.*:://;

	if ($ivars{$name}) {
		my $s = shift;
		if ($s) {
			$self->{$name} = $s;
		} else {
			return $self->{$name};
		}

	} elsif ($hash_vars{$name}) {
		if (scalar @_ == 1) {
			return $self->{$name}{$_[0]};	# return value by key
		} elsif (@_) {
			while (@_) {
				my $key = shift;
				$self->{$name}{$key} = shift; # set key/value pairs
			}
		} else {
			return $self->{$name};	# return a hash ref
		}

	} elsif ($set_vars{$name}) {
		if (@_) {
			$self->{$name}{$_} = 1 foreach @_;
			$self->{tbledit_arrays}{$name} = [@_];
		} else {
			return unless defined $self->{$name};
			return @{$self->{tbledit_arrays}{$name}} if wantarray;
			return scalar keys %{$self->{$name}};
		}

	} elsif ($name =~ s/^in_// && $set_vars{$name}) {
		my $key = shift;
		return $self->{$name}{$key} == 1;

	} else {
		die "Undefined method $AUTOLOAD called in TableEdit";
	}
}

sub search {
	my $self = shift;
	my ($cgi, $privs, $debug) = @_; ### pass in the query as a cgi obj
	my $dbh = $self->{dbh};
    
	# sort by a separate key if specified
	if (my $sortkey = $cgi->param('sortkey')) {
		$self->{order_by} = $sortkey;
	}

    # construct our query
    my ($query, $where) = $self->get_query($cgi, $privs);
	
	# fetch the data so we can count the rows
	my $sth = $dbh->prepare($query);
	$sth->execute();
	my $ary = $sth->fetchall_arrayref();

	my $result = {table => $self->{table}, fields => [$self->fields_for_priv($privs)], data => $ary};
	$result->{debug} = $where if $privs >= 16;
	return $result;
}


# Returns an SQL query based on the parameters passed to the script.
# actually returns two values: the first is the entire SQL query;
# the second is a string consisting of the WHERE and HAVING clauses,
# which is nicer to display to the user than the entire query string.
sub get_query {
	my $self = shift;
	my $cgi = shift;
	my $privs = shift;
	
	my ($where, $having) = $self->query_where($cgi);
	my $flds = join(', ', $self->fields_for_priv($privs, 'full'));
	my $from = $self->{query_from} || $self->{table};
	return "SELECT $flds FROM $from GROUP BY $self->{key} LIMIT 1", '[first item]' unless $where;
	
	my $order = $self->{order_by} || $self->{key};
	return "SELECT "
		. ($self->{select_distinct} ? 'DISTINCT ' : '')
		. "$flds FROM $from WHERE $where "
		. "GROUP BY $self->{key} "
		. ($self->{also_group_by} ? ", $self->{also_group_by} " : '')
		. ($having ? "HAVING $having " : '')
		. "ORDER BY $order LIMIT 20000", # a sane limit to prevent overburdening the database
		$where . ($having ? " HAVING $having" : '');
}

# helper WHERE bits
sub where_int { my ($k,$v) = @_; $v =~ /^([<>])(.+)/ ? "$k$1$2" : "$k=$v" }
sub where_rlike { my ($k,$v) = @_; "$k RLIKE '$v'" }
sub where_word { my ($k,$v) = @_; "$k RLIKE '[[:<:]]${v}[[:>:]]'" }
sub where_beginword { my ($k,$v) = @_; "$k RLIKE '[[:<:]]$v'" }

sub wheres {
	my $self = shift;
	if (scalar @_ == 1) {
		return $self->{wheres}{$_[0]};	# return value by key
	} elsif (@_) {
		while (@_) {
			my $key = shift;
			my $val = shift;
			$val = $preset_wheres{$val} || $val;
			$self->{wheres}{$key} = $val; # set key/value pairs
		}
	} else {
		return $self->{wheres};	# return a hash ref
	}
}

# generates the WHERE clause based on the CGI params
sub query_where {
	my $self = shift;
	my $cgi = shift;
	my (@wheres, @havings);
	my $query_ok = 0;
	
	for my $key ($cgi->param) {
		if ($self->{is_field}{$key} || $self->in_searchable($key) # make sure the field name is in one of these lists, just to be safe
			and (my $value = $cgi->param($key)) ne '') { # might be numeric 0, so must check for empty string
			$query_ok = 1;
			$value =~ s/'/''/g;	# security, don't let people put weird sql in here!
			$value =~ s/\\/\\\\/g;

			my @restrictions;
			for my $value (split /, */, $value) {
				# get the WHERE phrase for this key, if specified
				# otherwise, default to an int if it's a calculated field, a string (RLIKE) otherwise.
				my $sub = $self->wheres($key) || ($self->in_calculated_fields($key) ? \&where_int : \&where_rlike);
				push @restrictions, $sub->($key,$value);
			}
			# calculated fields should be searched for using a HAVING clause,
			# but make an exception for pseudo-fields - right now this means the former
			# lexicon.analysis field which is now calculated using a GROUP_CONCAT and is editable,
			# so we check if the key is editable
			if ($self->in_calculated_fields($key) && !$self->in_editable($key)) {
				push(@havings, "(" . join(" OR ", @restrictions) .")");
			} else {
				push(@wheres, "(" . join(" OR ", @restrictions) .")");
			}
		}
	}
	my $conj = ' AND ';
	if (scalar $self->search_by_disjunction()) {
		my @flds = $self->search_by_disjunction();
		my $n = grep { $cgi->param($_) ne '' } @flds;
		$conj = ' OR ' if $n == scalar @flds;
	}
	if ($query_ok) {
		return join($conj, @wheres) || 1, join($conj, @havings);
	}
	return;
}

sub save_value {
	my $self = shift;
	my ($field, $value, $id, $uid) = @_;
	
	die "bad field name passed in!" unless $self->in_editable($field); # this will help prevent sql injection attacks
	my $update = qq{UPDATE $self->{table} SET $field=? WHERE $self->{key}=?};
	my $update_sth = $self->{dbh}->prepare($update);
	$update_sth->execute($value, $id);

	my $sub = $self->save_hooks($field);
	$sub->($id, $value, $uid) if $sub;
}

sub delete_data {
	my $self = shift;
	my $cgi = shift;
	my $dbh = shift;
	my @params = $cgi->param;
	
	foreach my $param (@params) {
		if ($param =~ m/^delete_(.+)/) {
			my $id = $1;
			my $table = $self->{'table'};
			my $key = $self->{'key'};
			my $s = qq{DELETE FROM $table WHERE $key=?};
			my $delete_sth = $dbh->prepare($s);
			$delete_sth->execute($id);
		}
	}
}

1;
