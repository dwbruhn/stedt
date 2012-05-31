package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use Time::HiRes qw(time);

sub main : StartRunmode {
	my $self = shift;
	$self->require_privs(1);
	
	my %h;
	if ($self->has_privs(16)) {
		$h{num_sessions} = $self->dbh->selectrow_array("SELECT COUNT(*) FROM sessions");
	}
	return $self->tt_process("admin.tt", \%h);
}

sub changes : Runmode {
	my $self = shift;
	$self->require_privs(1);
	my ($tbl, $id) = ($self->query->param('t'), $self->query->param('id'));
	my $where = '';
	if ($tbl && $id) {
		$where = "WHERE `table`=? AND id=?";
	}
	my $sth = $self->dbh->prepare("SELECT users.username,change_type,accepted_tag,`table`,id,col,oldval,newval,
		owners.username,time FROM changelog LEFT JOIN users USING (uid)
		LEFT JOIN users AS owners ON (owner_uid=owners.uid)
		$where
		ORDER BY time DESC LIMIT 500");
	if ($tbl && $id) {
		$sth->bind_param(1, $tbl);
		$sth->bind_param(2, $id);
	}
	$sth->execute;
	my $a = $sth->fetchall_arrayref;
	return $self->tt_process("admin/changelog.tt", {changes=>$a});
}

sub where_word { my ($k,$v) = @_; $v =~ s/^\*(?=.)// ? "$k RLIKE '$v'" : "$k RLIKE '[[:<:]]${v}[[:>:]]'" }

sub updateprojects : Runmode {
	my $self = shift;
	$self->require_privs(1);
	my $t0 = time();
	require STEDT::RootCanal::stopwords;
	import STEDT::RootCanal::stopwords;

	my $a = $self->dbh->selectall_arrayref("SELECT id,project,subproject,querylex FROM projects LIMIT 500");
	# the loop below will add values for percent_done, tagged_reflexes, count_reflexes, and count_etyma

	# no need to use load_table_module and query_where to build the query string
	# because the query is so simple and it's better to optimize the regex
	# instead of using multiple OR's in the WHERE clause
	for my $row (@$a) {
		my $words = $row->[3];
		$words =~ tr/\\()//d; # remove backslashes and parens
		$words = join '|', split m|[,/] *|, $words; # split by commas and slashes, then rejoin with pipes
		my ($fulltext_words, $other_words) = mysql_fulltext_filter(split /\|/, $words);
		$fulltext_words = join ' ', @$fulltext_words;
		$other_words = join '|', @$other_words;
		if ($other_words) {
			$other_words = "($other_words)" if $other_words =~ /\|/;
			$other_words = qq#OR gloss RLIKE "[[:<:]]${other_words}[[:>:]]"#;
		} # otherwise it's empty and doesn't affect the search
		# $row->[3] = $other_words; # debugging - see how many "left over" glosses there are
		# count a lx_et_hash record as "ambiguous" below if it's '', 'm', or if any other lx_et_hash entries with the same rn are '' or 'm'
		my $counts = $self->dbh->selectall_arrayref(
			qq#SELECT COUNT(DISTINCT rn),
				lx_et_hash.rn IS NOT NULL AS has_tags,
				tag_str='' OR tag_str='m' OR 0<(SELECT COUNT(*) FROM lx_et_hash WHERE rn=lexicon.rn AND (tag_str='' OR tag_str='m')) AS is_ambiguous
			FROM lexicon LEFT JOIN lx_et_hash USING (rn)
			WHERE MATCH(gloss) AGAINST ("$fulltext_words" IN BOOLEAN MODE)
			$other_words
			GROUP BY 2,3#);
		my ($tagged, $not_tagged, $sorta_tagged) = (0,0,0);
		foreach (@$counts) {
			my ($count, $has_tags, $is_ambiguous) = @$_;
			if (!$has_tags) { $not_tagged = $count; }
			elsif ($is_ambiguous) { $sorta_tagged = $count; }
			else { $tagged = $count; }
		}
		my $total_found = $tagged + $sorta_tagged + $not_tagged;
		
		$row->[5] = $tagged . ($sorta_tagged ? "(+$sorta_tagged)" : '');
		$row->[6] = $total_found;
		$row->[4] = $total_found
			? sprintf("%.1f", 100 * $tagged/$total_found)
				. ($sorta_tagged
						? ' - ' . sprintf("%.1f", 100 * ($tagged+$sorta_tagged)/$total_found)
						: '')
			: "0.0"; # no dividing by zero!
		
		$row->[7] = $self->dbh->selectrow_array(qq#SELECT count(*) FROM etyma   WHERE protogloss RLIKE "[[:<:]]($words)[[:>:]]"#);
		$self->dbh->do("UPDATE projects SET tagged_reflexes=?,ambig_reflexes=?,count_reflexes=?,count_etyma=? WHERE id=?", undef,
			$tagged, $sorta_tagged, $total_found, $row->[7], $row->[0]);
		shift @$row;
	}
	
	return $self->tt_process("admin/updateprojects.tt", {
		projects=>$a,
		time_elapsed=>time()-$t0,
	});
}

sub queries : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $a = $self->dbh->selectall_arrayref("SELECT `table`,form,gloss,lg,lggroup,ip,time FROM querylog ORDER BY time DESC LIMIT 500");
	return $self->tt_process("admin/querylog.tt", {queries=>$a});
}

sub deviants : Runmode {
	my $self = shift;
	$self->require_privs(1);

	# count number of records with deviant glosses
	my %conditions = ('to VERB','^to [^/(]',
			'to be VERB','^to be ',
			'be VERB','^be [^/(]',
			'a(n) NOUN','^an? [^/(]',
			'the NOUN','^the ',
			'records with curly quotes','“|”|‘|’');
	foreach my $cond (keys %conditions)
	{
		$conditions{$cond} = {count=>$self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE `gloss` REGEXP '$conditions{$cond}'"),
				     regex=>$conditions{$cond}};
	}
		
	return $self->tt_process("admin/deviants.tt", {deviants=>\%conditions});
}

sub progress : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $a = $self->dbh->selectall_arrayref("SELECT username, users.uid,
			COUNT(DISTINCT tag), COUNT(DISTINCT rn)
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag)
		WHERE tag != 0 GROUP BY uid;");
	my $b = $self->dbh->selectall_arrayref("SELECT username,users.uid,
			tag, plg, protoform, protogloss, COUNT(DISTINCT rn) as num_recs
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag)
		WHERE users.uid !=8 AND tag != 0 GROUP BY uid,tag ORDER BY uid, num_recs DESC");
	
	# pull out "past work" from changelog and count what was done in the past, add these counts into table. Credit where credit is due!
	my %c = @{$self->dbh->selectcol_arrayref("SELECT owner_uid, COUNT(*) FROM changelog WHERE change_type='approval' GROUP BY owner_uid",
		{Columns=>[1,2]})};
	foreach my $row (@$a){
	  my $uid = $row->[1];
	  $c{$uid} ||= 0;
	  push @$row, $c{$uid}, @$row[3] + $c{$uid};
	  # add two columns: number of accepted taggings,
	  # and the total of the last two columns (reflexes + accepted)
	}
	return $self->tt_process("admin/progress.tt", {etymaused=>$a, tagging=>$b});
}

sub progress_detail : Runmode {
	my $self = shift;
	$self->require_privs(1);

	my $months = $self->dbh->selectcol_arrayref("SELECT CONCAT(YEAR(time), ' ', MONTHNAME(time)) FROM changelog WHERE change_type='approval' GROUP BY 1 ORDER BY YEAR(time) DESC, MONTH(time) DESC");
	my $a = $self->dbh->selectall_arrayref("SELECT CONCAT(YEAR(time), ' ', MONTHNAME(time)), username ,COUNT(*) FROM changelog LEFT JOIN users ON (changelog.owner_uid=users.uid) WHERE change_type='approval' GROUP BY 1,2");
	my (%u_totals, %m_totals, $grand_total);
	my %stats; # hash of month/user -> count
	foreach (@$a) {
		my ($y_m, $u, $count) = @$_;
		$stats{"$y_m"}{$u} = $count;
		$u_totals{$u} += $count;
		$m_totals{$y_m} += $count;
		$grand_total += $count;
	}
	return $self->tt_process("admin/progress_detail.tt", {
		stats=>\%stats,
		months=>$months,
		users=>[sort keys %u_totals],
		u_totals=>\%u_totals,
		m_totals=>\%m_totals,
		total => $grand_total
	});
}

sub listpublic : Runmode {
	my $self = shift;
	$self->require_privs(16);

	my $a = $self->dbh->selectcol_arrayref("SELECT tag FROM etyma WHERE public=1");
	return "[" . join(',', @$a) . "]";
}

# generate hard-coded javascript group numbers
sub listgrpnos : Runmode {
	my $self = shift;
	my %o2s;
	for (@{$self->dbh->selectall_arrayref("SELECT ord, grpno, grp from languagegroups ORDER BY grpno")}) {
		my ($ord,$grpno,$grp) = @$_;
		$grpno =~ s/(\.0)+$//;
		$o2s{$ord} = "$grpno. $grp" unless $o2s{$ord}; # only do this if it's the first one
	}
	require JSON;
	return JSON::to_json(\%o2s);
}

sub expire_sessions : Runmode {
	my $self = shift;
	$self->require_privs(16);
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
				$self->dbh->do("INSERT changelog (uid, `table`, id, col, oldval, newval, time)
								VALUES (?,?,?,?,?,?,NOW())", undef,
					$self->param('uid'), 'etyma', $tag, 'sequence', $oldval || '', $s);
			}
		}
	}
}

sub seq : Runmode {
	my $self = shift;
	$self->require_privs(8);
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
