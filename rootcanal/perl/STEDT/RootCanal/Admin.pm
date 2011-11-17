package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;

sub main : StartRunmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }
	
	my %h;
	if ($self->has_privs(16)) {
		$h{num_sessions} = $self->dbh->selectrow_array("SELECT COUNT(*) FROM sessions");
	}
	return $self->tt_process("admin.tt", \%h);
}

sub changes : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT username,`table`,col,id,oldval,newval,time FROM changelog LEFT JOIN users USING (uid) ORDER BY time DESC LIMIT 500");
	return $self->tt_process("admin/changelog.tt", {changes=>$a});
}

sub where_word { my ($k,$v) = @_; $v =~ s/^\*(?=.)// ? "$k RLIKE '$v'" : "$k RLIKE '[[:<:]]${v}[[:>:]]'" }

sub updateprojects : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT id,project,subproject,querylex,100 * tagged_reflexes/count_reflexes as pct,tagged_reflexes,count_reflexes,count_etyma FROM projects ");

	# would be nice to just make a call to Table::search to get the query strings...dunno how to do that yet!
	my $i = 0;
	foreach my $row (@$a) {
	  $i++;
	  last if ($i > 500);
	  my $glosses = $row->[3];
	  my $qstring = $row->[3];
	  my @restrictions;
	  # split by commas that are not preceded by a single backslash (allows searching for commas)
	  for my $value (split /(?<!(?<!\\)\\), */, $qstring) {
	    next if $value eq ''; # might be numeric 0, so must check for empty string
	    $value =~ s/(?<!\\)((?:\\\\)*)\\('|$)/$1$2/g;
	    $value =~ s/'/''/g; # escape all single quotes
	    push @restrictions, where_word('gloss',$value);
	  }
	  $qstring =  "(" . join(" OR ", @restrictions) .")";
	
	  $row->[5] = $self->dbh->selectrow_array("SELECT count(*) FROM lexicon WHERE $qstring AND analysis != ''");
	  $row->[6] = $self->dbh->selectrow_array("SELECT count(*) FROM lexicon WHERE $qstring");
	  $row->[4] = $row->[5] > 0 ?  sprintf("%.1f",(100 * $row->[5] / $row->[6])) : "0.0";
	  
	  $qstring =~ s/gloss/protogloss/g;
	  $row->[7] = $self->dbh->selectrow_array("SELECT count(*) FROM etyma   WHERE $qstring");
	  $self->dbh->do("UPDATE projects SET tagged_reflexes=?,count_reflexes=?,count_etyma=? WHERE id=?", undef, @$row[5,6,7,0]);
	  shift @$row;
	}
	
	return $self->tt_process("admin/updateprojects.tt", {projects=>$a});
}

sub queries : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,query,ip,time FROM querylog ORDER BY time DESC LIMIT 500");
	return $self->tt_process("admin/querylog.tt", {queries=>$a});
}

sub deviants : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	# count number of records with deviant glosses
	my %conditions = ('to VERB','^to ',
			'to be VERB','^to be ',
			'be VERB','^be [^/]',
			'a(n) NOUN','^an? ',
			'the NOUN','^the ',
			'records with curly quotes','“|”|‘|’');
	foreach my $cond (keys %conditions)
	{
		$conditions{$cond} = {count=>$self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE `gloss` REGEXP '$conditions{$cond}'"),
				     regex=>$conditions{$cond}};
	}
		
	return $self->tt_process("admin/deviants.tt", {deviants=>\%conditions});
}

sub users : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT username,uid,email,privs,COUNT(DISTINCT rn) FROM users LEFT JOIN lx_et_hash USING (uid) GROUP BY uid");
	return $self->tt_process("admin/users.tt", {users=>$a});
}

sub progress : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(1)) { return $err; }

	my $a = $self->dbh->selectall_arrayref("SELECT username, users.uid,
			COUNT(DISTINCT tag), COUNT(DISTINCT rn)
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag)
		WHERE tag != 0 GROUP BY uid;");
	my $b = $self->dbh->selectall_arrayref("SELECT username,users.uid,
			tag, protoform, protogloss, COUNT(DISTINCT rn) as num_recs
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag)
		WHERE users.uid !=8 AND tag != 0 GROUP BY uid,tag ORDER BY uid, num_recs DESC");
	
	# pull out "past work" from changelog and count what was done in the past, add these counts into table. Credit where credit is due!
	my $x = $self->dbh->selectall_arrayref("SELECT oldval,newval FROM changelog WHERE col = '=accept';");
	my %c ;
	foreach my $row (@$x) {
	  (my $tagger) = $row->[0] =~ m/^uid=(\d+)/;
	  my $rns = $row->[1];
	  my $count = scalar split(',',$rns);
	  $c{$tagger} += $count;
	}
	foreach my $row (@$a){
	  my $uid = $row->[1];
	  push @$row, $c{$uid} || 0, @$row[3] + $c{$uid};
	  # add two columns: number of accepted taggings,
	  # and the total of the last two columns (reflexes + accepted)
	}
	return $self->tt_process("admin/progress.tt", {etymaused=>$a, tagging=>$b});
}


sub listpublic : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(16)) { return $err; }

	my $a = $self->dbh->selectcol_arrayref("SELECT tag FROM etyma WHERE public=1");
	return "[" . join(',', @$a) . "]";
}

sub expire_sessions : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(16)) { return $err; }
	local *STDOUT; # override STDOUT since ExpireSessions stupidly prints to it
	open(STDOUT, ">", \my $tmp) or die "couldn't open memory file: $!";
	require CGI::Session::ExpireSessions;
	import CGI::Session::ExpireSessions;
	CGI::Session::ExpireSessions->new(dbh=>$self->dbh,
		delta=>2551443,
		verbose=>1)->expire_db_sessions;
	# mean length of synodic month is approximately 29.53059 days
	return "<pre>$tmp</pre>";
}

sub save_seq {
	my $self = shift;
	my $t = $self->load_table_module('etyma');
	require JSON;
	my $seqs = JSON::from_json($_[0]);
	for my $i (0..$#{$seqs}) {
		my $etyma = $seqs->[$i];
		my $num_etyma = @$etyma;
		my $is_paf;
		my $j = 1;
		for my $tag (@$etyma) {
			if ($tag eq 'P') {
				$is_paf = 1;
				next;
			}
			my $s;
			if ($is_paf || $num_etyma == 1) {
				$s = $i;
				$is_paf = 0;
			} elsif ($i == 0) {
				$s = 0;
			} else {
				$s = "$i.$j";
				$j++;
				$j = 9 if $j > 9;
			}
			my $oldval = $t->get_value('etyma.sequence', $tag);
			
			if ($oldval != $s) {
				$t->save_value('etyma.sequence', $s, $tag);
				$self->dbh->do("INSERT changelog VALUES (?,?,?,?,?,?,NOW())", undef,
					$self->param('uid'), 'etyma', 'sequence', $tag, $oldval || '', $s);
			}
		}
	}
}

sub seq : Runmode {
	my $self = shift;
	if (my $err = $self->require_privs(8)) { return $err; }
	my $chap = $self->query->param('c');
	return "no chapter specified!" unless $chap;

	my $msg;
	if ($self->query->param('seqs')) {
		$self->save_seq($self->query->param('seqs'));
		$msg = "Success!";
	}

	my $a = $self->dbh->selectall_arrayref("SELECT tag, protoform, protogloss, sequence FROM etyma WHERE tag=supertag AND chapter=? ORDER BY sequence", undef, $chap); # no mesoroots should go in this list!
	
	# run through results and group allofams
	my @fams;
	my $last_seq = 0;
	push @fams, {seq=>0, allofams=>[]}; # always have a #0 for unsequenced tags
	foreach (@$a) {
		my %e;

		# prettify protoform
		@e{qw/tag form gloss seq/} = @$_;
		$e{form} =~ s/⪤ +/⪤ */g;
		$e{form} =~ s/OR +/OR */g;
		$e{form} =~ s/~ +/~ */g;
		$e{form} =~ s/ = +/ = */g;
		$e{form} = '*' . $e{form};

		# transmogrify sequence number
		my $seq = int $e{seq}; # truncate the sequence number
		$e{seq} =~ s/^\d+\.//;
		$e{seq} =~ s/0+$//;
		if ($e{seq}) {
			$e{seq} =~s/(\d)/$1 ? chr(96+$1) : '-'/e;
		}
		
		if ($seq != $last_seq) {
			push @fams, {seq=>$seq, allofams=>[\%e]};
			$last_seq = $seq;
		} else {
			push @{$fams[-1]{allofams}}, \%e;
		}
	}
	# de-allofam
	# make PAF

	return $self->tt_process("admin/sequencer.tt", {fams=>\@fams, msg=>$msg});
}

1;
