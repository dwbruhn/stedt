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
  my ($file,$fh,$upload_dir) = @_;

  open (UPLOADFILE, ">$upload_dir/$file") or die "$!";
  binmode UPLOADFILE;
  
  while ( <$fh> )
    {
      print UPLOADFILE;
    } 
  close UPLOADFILE;
  seek($fh,0,0);
}

sub getheader {
      $_ = shift;
      @header = split "\t";
      for (my $i = 0; $i < scalar @header; $i++) {
        if ($header[$i] !~ /\b(gloss|reflex|pos|id)\b/) {
	  # $show_stopper = 1;
	  push(@messages, $header[$i]. ': this header value is not used; column will be ignored.');
	}
	else {
	  push(@messages, $header[$i]. " header column found: $i");
	}
        $headerindex{$header[$i]} = $i;
      }
}

sub validateMetadata {
  my $metaref = shift;
  my %metadata = %{$metaref};
  my @metatadatafields = shift;
  foreach my $f (keys %metadata) {
	print STDERR "$f:  $metadata{$f}\n";
  }
  my @m;
  my %results;
  my @messages;
    push(@messages, ' everything is fine for now');
  my $show_stopper = 1;
  $results{'status'}   = $show_stopper ? "Metadata OK!" : "Sorry, your metadata has some problems." ;
  $results{'messages'} = \@messages;
  $results{'metadata'} = \@m;
  return %results;
  }

sub validateContribution {
  my $fh = shift;
  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  my $problems = 0;
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
        if ($columns[$i] =~ /[^\w\s;\,\(\)\.\'\"\/\-\!\:]/) {
          push(@messages, "unusual character(s) in column 'gloss' <i>$columns[$i]</i>, line $lines");
          $show_stopper = 1 ;
	  $problems++;
          }
	# check if gloss exists
	if ($column eq '') {
	  push(@messages, 'no gloss.');
	  $show_stopper = 1 ;
	  $problems++;
	}
      }
      if ($i == $headerindex{'reflex'}) {
	# do reflex tests
	# check if reflex exists
	    if ($column eq '') {
	      push(@messages, 'no reflex.');
	      $show_stopper = 1 ;
	      $problems++;
	}
        if ($columns[$i] =~ /[";.\?]/) {
          push(@messages, "unusual characters in column 'reflex' ($columns[$i]), line $lines");
          $show_stopper = 1;
	  $problems++;
        }
      }
      if ($i == $headerindex{'pos'}) {
	# do part-of-speech tests
	# it is OK if pos field is empty!
      }
      if ($i == $headerindex{'id'}) {
	# check ID
	# it is OK if ID field is empty!
      }
    }
  }
  push(@messages, $lines . ' lines read, including header. ' . $problems . ' problems identified.');
  $results{'status'}   = $show_stopper ? "Sorry, your file doesn't meet standards." : "File content OK!";
  $results{'messages'} = \@messages;
  seek($fh,0,0);
  return %results;
}

sub load2db {
  my ($file,$dbh,$upload_dir,@m) = @_;
  
  #print STDERR 'file', $file;

  open (INPUTFILE, "<:encoding(UTF-8)", "$upload_dir/$file" ) or die "$!";
  binmode INPUTFILE;

  my %results;
  my $lines;
  my $header_length;
  my $row_length;
  my @messages;
  # create new language names and source bib records
  my $lgsort = $m[0];
  $lgsort =~ tr/a-z/A-Z/;
  $lgsort =~ s/ //g;
  my $srcabbrExists = $dbh->selectrow_array("SELECT COUNT(*) FROM srcbib WHERE srcabbr=?", undef, $m[2]);
  if ($srcabbrExists) {
    push(@messages, '<span style="color:red">The srcabbr "' . $m[2] . '" already exists! Undo if this is not what you want!</span>');
  }
  else {
    $dbh->do("INSERT srcbib (srcabbr, author, year, title, citation) values (?,?,?,?,?)", undef, $m[2],$m[3],$m[4],$m[5],$m[6]);
  }
  # find the lgcode value, if one exists. if not, make one up.
  my $lgcode;
  $lgcode= $dbh->selectrow_array("SELECT lgcode FROM languagenames WHERE lgsort=?", undef, $lgsort);
  unless ($lgcode) {
     $lgcode = $dbh->selectrow_array("select max(lgcode) from languagenames");
     $lgcode += 1;
  }
  print STDERR 'lgcode: ' . $lgcode . ' lgsort: ' . $lgsort . ' grpid: ' . $m[9];
  $dbh->do("INSERT languagenames (language, lgabbr, lgsort, srcabbr, lgcode, grpid) values (?,?,?,?,?,?)", undef, $m[0],$m[1],$lgsort,$m[2],$lgcode, $m[9]);
  my $lgid = $dbh->selectrow_array("SELECT LAST_INSERT_ID();");
  while (<INPUTFILE> ) {
    chomp;
    $lines++;
    # check header
    if ($lines == 1) {
      getheader($_);
      next;
    }
    #print STDERR  $lines . ' lines read.';
    my @columns = split "\t";
    my $gloss  = @columns[ $headerindex{'gloss'} ];
    my $reflex = @columns[ $headerindex{'reflex'} ];
    my $srcid  = $headerindex{'id'} ? @columns[ $headerindex{'id'} ] : '';
    my $pos    = $headerindex{'pos'} ? @columns[ $headerindex{'pos'} ] : '';
    my $semkey = '';
    $dbh->do("INSERT lexicon (reflex, gloss, gfn, lgid, semkey, srcid) values (?,?,?,?,?,?)", undef, $reflex,$gloss,$pos || '',$lgid,$semkey,$srcid || '');
  }
  push(@messages, $lines-1 . ' lines loaded');
  #print STDERR  $lines-1 . ' lines loaded';
  $results{'status'} = "name of file is: $file";
  $results{'language id'} = $lgid;
  $results{'source abbr'} = $m[2];
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
  my $filename = $self->query->param('filename');
  my $file = $self->query->param('contribution');
  my $lgid;
  my $srcabbrsave;
  my $upload_dir = '/tmp';
  my $metadatafields = ['language', 'lgabbr', 'srcabbr', 'author', 'year', 'title', 'citation', 'contributor', 'email'];
  my %metadata;
  my %results;
  my @validation;
  if ($step eq 'thanks') {
    $srcabbrsave = $self->query->param('srcabbrsave');
    $lgid = $self->query->param('lgid');
    # ...but no thanks; if we are here, user must want to delete their data..
    $self->dbh->do("DELETE FROM lexicon WHERE lgid=?", undef, $lgid);
    $self->dbh->do("DELETE FROM srcbib WHERE srcabbr=?", undef, $srcabbrsave);
    $self->dbh->do("DELETE FROM languagenames WHERE lgid=?", undef, $lgid);
    $step = 'upload';
  }
  elsif ($step eq 'upload') {
    if ($file) {
      # upload file
      my $fh = $self->query->upload('contribution');
      $filename = $file;
      uploadFile($file,$fh,$upload_dir);
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
    my @m;
    foreach my $f (@$metadatafields) {
      if ($metadata{$f}) {
	push @m,$metadata{$f};
	print STDERR "$f:  $metadata{$f}\n";
      }
      else {
	push @m,'';
	print STDERR "$f:  empty\n";
      }
    }
    push @m,$metadata{'grpid'};
    # check metadata
    %results = validateMetadata(\%metadata,$metadatafields);
    @validation = @{$results{'messages'}};
    if ($results{'status'} =~ /Sorry/) {
      # oops try again!
      $step = 'metadatafailure';
    }
    else {
      # load to database
      %results = load2db($filename,$self->dbh,$upload_dir,@m);
      $lgid = $results{'language id'};
      $srcabbrsave = $results{'source abbr'};
      @validation = @{$results{'messages'}};
      $step = 'thanks';
    }
  }
  else {
    # $step not set, must be first pass through: set current step to upload.
    $step = 'upload';
  }

  foreach my $v (@validation) {
    print STDERR "contribution INFO:  $v\n";
  }

 my $grpids = $self->dbh->selectall_arrayref("SELECT grpid,grpno,grp FROM languagegroups ORDER BY grp0,grp1,grp2,grp3,grp4 LIMIT 200");

  return $self->tt_process("admin/contribution.tt", {
		step=>$step,
		filename=>$filename,
		file=>$file,				     
		lgid=>$lgid,			     
		srcabbrsave=>$srcabbrsave,
		grpids=>$grpids,
		messages=>$results{'status'},
		provided=>\%metadata,
		validation=>\@validation,
		metadata=> $metadatafields
		});
		
}

sub bulkapproval : Runmode {
  my $self = shift;
  $self->require_privs(8);
  # takes a list of tags and "approves" all non-STEDT tags for the selected user.
  # everything is done via AJAX in the template. Nothing else to do here!
  my $users = $self->dbh->selectall_arrayref("SELECT distinct username,uid FROM lx_et_hash
  	LEFT JOIN users USING (uid)
  	WHERE uid!=8
  	ORDER BY username LIMIT 500");
  return $self->tt_process("admin/bulkapproval.tt", {users => $users });
}

sub bulktag : Runmode {
  my $self = shift;
  $self->require_privs(8);
  # takes a list of rns and a tag and tags all the specified rns for the selected user.
  # everything is done via AJAX in the template. Nothing else to do here!
  my $users = $self->dbh->selectall_arrayref("SELECT distinct username,uid FROM lx_et_hash
  	LEFT JOIN users USING (uid)
  	WHERE uid!=8
  	ORDER BY username LIMIT 500");
  return $self->tt_process("admin/bulktag.tt", {users => $users });
}

sub deletedata : Runmode {
  my $self = shift;
  $self->require_privs(8);
  my $msg;
  # Deletes the data specified
  my $srcabbrs = $self->dbh->selectall_arrayref("SELECT distinct srcabbr FROM srcbib ORDER BY srcabbr LIMIT 500");

  if ($self->query->param('srcabbr') ne "") {
    my $srcabbr = $self->query->param('srcabbr');
    my $lgid = $self->query->param('lgid');
    if ($lgid ne '') {
      my $checksrcabbr = $self->dbh->selectrow_array("SELECT srcabbr FROM `languagenames` WHERE lgid=?", undef, $lgid);
      if ($checksrcabbr ne $srcabbr) {
	$msg = "source abbreviation for $lgid is '$checksrcabbr', not '$srcabbr'; no deleting done";
	return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
      }
    }
    else {
      my $checklgid = $self->dbh->selectrow_array("SELECT lgid FROM `languagenames` WHERE srcabbr=? LIMIT 1", undef, $srcabbr);
      if ($lgid ne $checklgid) {
	$msg = "lgid for $srcabbr is '$checklgid', not '$lgid'; no deleting done";
	return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
      }
    }
    my $count = $self->dbh->selectrow_array("SELECT count(*) FROM `lexicon` WHERE lgid=?", undef, $lgid);
    $self->dbh->do("DELETE FROM lexicon WHERE lgid=?", undef, $lgid);
    $self->dbh->do("DELETE FROM languagenames WHERE lgid=?", undef, $lgid);
    $msg = "Deleting source: '$srcabbr', lgid=$lgid";
    $msg .= "<br>$count lexicon records deleted.";
    if ($self->query->param('delsrc')) {
      my $lgcount = $self->dbh->selectrow_array("SELECT count(*) FROM `languagenames` WHERE srcabbr=?", undef, $srcabbr);
      if ($lgcount == 0) {
	$msg .= '<br>Deleted source bibliography entry as well.';
	$self->dbh->do("DELETE FROM srcbib WHERE srcabbr=?", undef, $srcabbr);
      }
      else {
	$msg .= "<br>Source bibliography entry not deleted! $lgcount language record(s) remain which refer to this source!";
      }
    }
  }

  return $self->tt_process("admin/deletedata.tt", {srcabbrs => $srcabbrs, msg => $msg });
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
