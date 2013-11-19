package STEDT::RootCanal::Admin;
use strict;
use base 'STEDT::RootCanal::Base';
use utf8;
use Time::HiRes qw(time);

my @messages;
my $show_stopper = 0;
my @header; 
my %headerindex;

sub main : StartRunmode {
	my $self = shift;
	$self->require_privs(2);
	
	my %h;
	if ($self->has_privs(16)) {
		$h{num_sessions} = $self->dbh->selectrow_array("SELECT COUNT(*) FROM sessions");
	}
	return $self->tt_process("admin.tt", \%h);
}

sub updatesequence : Runmode {
	my $self = shift;
	$self->require_privs(8);
	my $t0 = time();
	my @commands = ( 'update etyma set sequence = 0 where seqlocked = 0;',
			 'UPDATE etyma SET refcount = 0;',
			 'UPDATE etyma SET refcount = (SELECT COUNT(tag) FROM lx_et_hash WHERE lx_et_hash.tag = etyma.tag  AND uid = 8 GROUP by tag);',
			 'UPDATE etyma SET refcount = 0 where refcount is NULL;',
			 'update etyma set sequence = (select @rownum:=@rownum+1 rownum FROM (SELECT @rownum:=1000) r) where seqlocked = 0 order by refcount desc;' );
	foreach my $cmd (@commands) {
	  $self->dbh->do($cmd);
	}
	
	return $self->tt_process("admin/updatesequence.tt", {
		time_elapsed=>time()-$t0,
	});

}

sub uploadFile {
  my ($file,$fh) = @_;
  my $upload_dir = '/tmp';

  open (UPLOADFILE, ">$upload_dir/$file" ) or die "$!";
  binmode UPLOADFILE;
  
  while ( <$fh> )
    {
      print UPLOADFILE;
    } 
  close UPLOADFILE;
  seek($fh,0,0);
}


sub loaddbna {
  my (%metadata,$file) = @_;
  my $upload_dir = '/tmp';

  open (INPUTFILE, "<:encoding(UTF-8)", "$upload_dir/$file" ) or die "$!";
  binmode INPUTFILE;
  
  while ( <INPUTFILE> )
    {
      # read line, insert into lexicon
    } 
  close INPUTFILE;
}

sub getheader {
      $_ = shift;
      @header = split "\t";
      for (my $i = 0; $i < scalar @header; $i++) {
        if ($header[$i] !~ /(gloss|reflex|pos)/) {
	  $show_stopper = 1;
	  push(@messages, $header[$i]. ' unexpected header column found.');
	}
	else {
	  push(@messages, $header[$i]. " header column found: $i");
	}
        $headerindex{$header[$i]} = $i;
      }
}

sub validateMetadata {
  my $fh = shift;
  my %results;
  my @messages;
    push(@messages, ' everything is fine for now');
  $show_stopper = 1;
  $results{'status'}   = $show_stopper ? "Your metadata is no good." : "Metadata OK!";
  $results{'messages'} = \@messages;
  return %results;
  }

sub validateContribution {
  my $fh = shift;
  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  while ( <$fh> ) {
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      getheader($_);
    }
    # So in the case of the test files, $headerindex{'gloss'} is 1.
    # Now you can test the columns in the rest of the file:
    
    # check for missing values
    my @columns = split "\t";
    for (my $i = 0; $i < scalar @header; $i++) {
      my $column = $columns[$i];
      if ($i == $headerindex{'gloss'}) {
        #print "@columns[$i]\n";
	# do gloss tests 
		# check well-formedness of gloss --- right now, checks for non-word characters in gloss; perhaps can be refined later
        if ($columns[$i] =~ /[^\w\s;\,\(\)\.\'\"\/\-]/) {
          push(@messages, "unusual character(s) in column 'gloss' <i>$columns[$i]</i>, line $lines");
          $show_stopper = 1 ;
          }
	# check if gloss exists
	if ($column eq '') {
	  push(@messages, 'no gloss.');
	  $show_stopper = 1 ;
	}
      }
      if ($i == $headerindex{'reflex'}) {
	# do reflex tests
	# check if reflex exists
	    if ($column eq '') {
	      push(@messages, 'no reflex.');
	      $show_stopper = 1 ;
	}
        if ($columns[$i] =~ /['";.?]/) {
          push(@messages, "unusual characters in column 'reflex' ($columns[$i]), line $lines");
          $show_stopper = 1;
        }
      }
      if ($i == $headerindex{'pos'}) {
	# do pos tests
	# it is OK if pos field is empty!
      }
      # check POS if present
    }
  }
  push(@messages, $lines . ' lines read, including header');
  $results{'status'}   = $show_stopper ? "Sorry, your file doesn't meet standards." : "File content OK!";
  $results{'messages'} = \@messages;
  seek($fh,0,0);
  return %results;
}

sub load2db {
#  my (%metadata) = shift;
  my ($file,$dbh) = @_;
  my $upload_dir = '/tmp';
  
  print STDERR 'file', $file;

  open (INPUTFILE, "<:encoding(UTF-8)", "$upload_dir/$file" ) or die "$!";
  binmode INPUTFILE;

  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  my @messages;
  while (<INPUTFILE> ) {
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      getheader($_);
    }
    my @columns = split "\t";
    my $gloss  = @columns[ $headerindex{'gloss'} ];
    my $reflex = @columns[ $headerindex{'reflex'} ];
    my $pos    = @columns[ $headerindex{'pos'} ];
    my $semkey = '';
    my $lgid = 3000;
    $dbh->do("INSERT lexicon (reflex, gloss, gfn, lgid, semkey) values (?,?,?,?,?)", undef, $reflex,$gloss,$pos,$lgid,$semkey);


    my @columns = split "\t";
#    push(@columns, $metadata{'language'}, $metadata{'source'});

  }
  push(@messages, $lines-1 . ' lines loaded');
  $results{'status'} = "file loaded.";
  $results{'messages'} = \@messages;
  return %results;
}

sub contribution : Runmode {
  # "contribution wizard" has 3 steps:
  # upload file - uses standard CGI file upload
  # metadata - if file validates, ask user for metadata
  # thanks - if metadata is ok, do the right thing with all the data, thank user
  # (file|metadata)failure - send user back a step if there is a problem.
  my $self = shift;
  $self->require_privs(8);
  my $step = $self->query->param('step');
  my $file = $self->query->param('contribution');
  my %metadata;
  my %results;
  my @validation;
  if ($step eq 'upload') {
    if ($file) {
      # upload file
      my $fh = $self->query->upload('contribution');
      uploadFile($file,$fh);
      # validate it
      %results = validateContribution($fh);
      @validation = @{$results{'messages'}};
      if ($results{'status'} =~ /Sorry/) {
	# oops try again!
	$step = 'filefailure';
      }
      else {
	# on to metadata!
	$step = 'metadata';
      }
    }
    else {
      # user did not give us a file. keep asking!
      $step = 'upload';
      $results{'status'} = 'No file provided!';
    }
  }
  elsif ($step eq 'metadata') {
    # process & validate metadata
    foreach my $element ($self->query->param) {
      next if $element =~ /^(btn|step)$/; # skip these
      $metadata{$element} = $self->query->param($element) if $self->query->param($element);
    }
    # check metadata
    %results = validateMetadata(%metadata);
    @validation = @{$results{'messages'}};
    if ($results{'status'} =~ /Sorry/) {
      # oops try again!
      $step = 'metadatafailure';
    }
    else {
      # load to database
      %results = load2db($file,$self->dbh);
      @validation = @{$results{'messages'}};
      $step = 'thanks';
    }
  }
  else {
    # $step not set, must be first pass through: set current step to upload.
    $step = 'upload';
  }
  

  foreach my $v (@validation) {
    print STDERR "v:  $v\n";
  }
  return $self->tt_process("admin/contribution.tt", {
		step=>$step,
		file=>$file,
		message=>$results{'status'},
		provided=>\%metadata,
		validation=>\@validation,
		metadata=> ['language','language abbreviation','source','author','year','contributor','email']
		});
		
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
	$self->require_privs(8);
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
		
		$row->[7] = $self->dbh->selectrow_array(qq#SELECT count(*) FROM etyma WHERE protogloss RLIKE "[[:<:]]($words)[[:>:]]" AND status != 'DELETE'#);
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
	$self->require_privs(8);

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
			tag, languagegroups.plg, protoform, protogloss, COUNT(DISTINCT rn) as num_recs
		FROM users LEFT JOIN lx_et_hash USING (uid) LEFT JOIN etyma USING (tag) LEFT JOIN languagegroups USING (grpid)
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

1;
