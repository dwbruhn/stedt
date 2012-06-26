package STEDT::RootCanal::Chapters;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use Time::HiRes qw(time);

sub browser : StartRunMode {
	my $self = shift;
	my $t0 = time();
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
	unless ($self->has_privs(1)) {
		$public = "AND etyma.public=1";
		$blessed = 'AND etyma.uid=8';
		$public_ch = 'HAVING num_public OR public_notes';
	}
	# from the chapters table
	my $chapterquery = <<SQL;
SELECT chapters.semkey, chapters.chaptertitle, 
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND public=1 $blessed) AS num_public,
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey $blessed),
	COUNT(DISTINCT notes.noteid), MAX(notes.notetype = 'G'), MAX(notes.notetype != 'I') as public_notes,
        chapters.semcat, chapters.old_chapter, chapters.old_subchapter, chapters.id
FROM chapters LEFT JOIN notes ON (notes.id=chapters.semkey)
GROUP BY 1 $public_ch ORDER BY v,f,c,s1,s2,s3
SQL
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);
	# chapters that appear in etyma but not in chapters table
	my $e_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT etyma.chapter, SUM(etyma.public), COUNT(*)
FROM etyma LEFT JOIN chapters ON (etyma.chapter=chapters.semkey)
WHERE chapter != ''  $public $blessed AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL
	# chapters that appear in notes but not in chapters table
	my $n_ghost_chaps = $self->dbh->selectall_arrayref(<<SQL);
SELECT notes.id, COUNT(notes.noteid), COUNT(etyma.tag)
FROM notes LEFT JOIN chapters ON (notes.id=chapters.semkey) LEFT JOIN etyma ON (etyma.chapter=chapters.semkey)
WHERE notes.spec='C' AND chapters.chaptertitle IS NULL GROUP BY 1 ORDER BY 1
SQL

	return $self->tt_process('chapter_browser.tt', {
		ch=>$chapters, e=>$e_ghost_chaps, n=>$n_ghost_chaps, time_elapsed=>sprintf("%0.3g", time()-$t0)
	});
}

# this was meant to be a way to manipulate the semtree, but
# for now it means "show all the glosswords and not the other columns"
sub tweak : RunMode {
	my $self = shift;
	my $t0 = time();
	my $public = '';
	my $blessed = '';
	my $public_ch = '';
	unless ($self->has_privs(1)) {
		$public = "AND etyma.public=1";
		$blessed = 'AND etyma.uid=8';
		$public_ch = 'HAVING num_public OR public_notes';
	}
	my $chapterquery = <<SQL;
SELECT chapters.semkey, chapters.chaptertitle, 
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey AND public=1 $blessed) AS num_public,
	(SELECT COUNT(*) FROM etyma WHERE chapter=chapters.semkey $blessed),
	COUNT(DISTINCT notes.noteid), MAX(notes.notetype = 'G'), MAX(notes.notetype != 'I') as public_notes,
	chapters.semcat, chapters.old_chapter, chapters.old_subchapter, chapters.id,
	COUNT(DISTINCT glosswords.word),
	GROUP_CONCAT(DISTINCT glosswords.word SEPARATOR ', ') AS some_glosswords,
	(SELECT COUNT(*) FROM lexicon WHERE lexicon.semkey=chapters.semkey) AS wcount
FROM chapters LEFT JOIN notes ON (notes.id=chapters.semkey) LEFT JOIN glosswords ON (chapters.semkey=glosswords.semkey)
GROUP BY 1 $public_ch ORDER BY v,f,c,s1,s2,s3
SQL
	# allow long GROUP_CONCAT's.
	my (undef, $max_len) = $self->dbh->selectrow_array("SHOW VARIABLES WHERE Variable_name='max_allowed_packet'");
	die "oops couldn't get max_allowed_packet from mysql" unless $max_len;
	$self->dbh->do("SET SESSION group_concat_max_len = $max_len");
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);
	return $self->tt_process('chapter_tweaker.tt', {
		ch=>$chapters, time_elapsed=>sprintf("%0.3g", time()-$t0)
	});
}

sub grid : RunMode {
	my $self = shift;
	$self->require_privs(1); # since this provides links to edit/etyma and edit/chapters, for now we restrict this to "tagger" privileges until we sort out if/how to present this to the public
	my $chapterquery = <<SQL;
SELECT v,f,
	(SELECT chaptertitle FROM chapters WHERE v=chaps.v AND f=chaps.f AND c=0 AND s1=0 AND s2=0 AND s3=0 ) AS title,
	(SELECT COUNT(*) FROM etyma WHERE chapter=CONCAT(v,'.',f) OR chapter LIKE CONCAT(v,'.',f,'.%')) AS num_etyma,
	COUNT(*) AS num_chapters
FROM chapters AS chaps
WHERE v<=10 AND f>0
GROUP BY f,v
SQL
	# order by fascicle 1st, so we can output a table easily.
	my $chapters = $self->dbh->selectall_arrayref($chapterquery);
	my $volumes = $self->dbh->selectcol_arrayref("SELECT chaptertitle FROM chapters WHERE v<=10 AND f=0 AND c=0 AND s1=0 AND s2=0 AND s3=0 ORDER BY v");
	return $self->tt_process('semantic_grid.tt', {
		ch => $chapters,
		vols => $volumes,
	});
}

sub chapter : RunMode {
	my $self = shift;
	my $tag = $self->param('tag');
	my $chap = $self->param('chap');
	my $title = $self->dbh->selectrow_array("SELECT chaptertitle FROM chapters WHERE semkey=?", undef, $chap);
	$title ||= '[chapter does not exist in chapters table!]';
	
	my $INTERNAL_NOTES = $self->has_privs(1);
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;
	my (@notes, @footnotes);
	my $footnote_index = 1;
	require STEDT::RootCanal::Notes;
	import STEDT::RootCanal::Notes;
	foreach (@{$self->dbh->selectall_arrayref("SELECT noteid, notetype, datetime, xmlnote, ord, uid, username FROM notes LEFT JOIN users USING (uid)"
			. "WHERE spec='C' AND id=? $internal_note_search ORDER BY ord", undef, $chap)}) {
		my $xml = $_->[3];
		push @notes, { noteid=>$_->[0], type=>$_->[1], lastmod=>$_->[2], 'ord'=>$_->[4],
			text=>xml2html($xml, $self, \@footnotes, \$footnote_index, $_->[0]),
			markup=>xml2markup($xml), num_lines=>guess_num_lines($xml),
			uid=>$_->[5], username=>$_->[6]
		};
	}
	
	my $t = $self->load_table_module('etyma');
	my $q = $self->query->new('');
	$q->param('etyma.chapter'=>$chap);
	$q->param('etyma.sequence'=>'>0'); # hide non-sequenced items from the chapter view
	$q->param('etyma.public'=>1) unless $self->has_privs(1);
	my $result = $t->search($q);
	
	return $self->tt_process("chapter.tt", {
		chap => $chap, chaptitle=>$title,
		notes  => \@notes,
		footnotes => \@footnotes,
		result => $result
	});
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

	my $a = $self->dbh->selectall_arrayref("SELECT tag, protoform, protogloss, sequence FROM etyma WHERE tag=supertag AND chapter=? AND status != 'DELETE' ORDER BY sequence", undef, $chap); # no mesoroots should go in this list!
	
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
