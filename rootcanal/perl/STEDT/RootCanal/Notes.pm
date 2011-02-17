package STEDT::RootCanal::Notes;
use strict;
use base 'STEDT::RootCanal::Base';
use Encode;
use utf8;

sub _tag2info {
	my ($t, $s, $dbh) = @_;
	my @a = $dbh->selectrow_array("SELECT etyma.protoform,etyma.protogloss FROM etyma WHERE tag=?", undef, $t);
	return "[ERROR! Dead etyma ref #$t!]" unless $a[0];
	my ($form, $gloss) = map {decode_utf8($_)} @a;
	$form =~ s/-/‑/g; # non-breaking hyphens
	$form =~ s/^/*/;
	$form =~ s/⪤ /⪤ */g;		# add a star for proto-allofams
	$form =~ s|(\*\S+)|<b>$1</b>|g; # bold the protoform but not the allofam sign or gloss
	if ($s) {			# alternative gloss, add it in
		$s = "$form $s";
	} else {
		$s = "$form $gloss"; # put protogloss if no alt given
	}
	return $s;
}

sub _nonbreak_hyphens {
	my $s = $_[0];
	$s =~ s/-/‑/g;
	return $s;
}

my @italicize_abbrevs =
qw|GSR GSTC STC HPTB TBRS TSR AHD VSTB TBT HCT LTBA BSOAS CSDPN TIL OED|;

# returns the note, and an array of footnotes in html
sub xml2html {
	local $_ = shift;
	my ($dbh, $footnotes, $i) = @_; # array ref and an index
	s|<par>|<p>|g;
	s|</par>|</p>|g;
	s|<emph>|<i>|g;
	s|</emph>|</i>|g;
	s|<gloss>(.*?)</gloss>|$1|g;	# no formatting?
	s|<reconstruction>\*(.*?)</reconstruction>|"<b>*" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<xref ref="(\d+)">#\1(.*?)</xref>|_tag2info($1,$2,$dbh)|ge;
	s|<footnote>(.*?)</footnote>|push @$footnotes, $1; qq(<a href="#foot$$i" id="toof$$i"><sup>) . $$i++ . "</sup></a>"|ge;
	s|<hanform>(.*?)</hanform>|$1|g;
	s|<latinform>(.*?)</latinform>|"<b>" . _nonbreak_hyphens($1) . "</b>"|ge;
	s|<plainlatinform>(.*?)</plainlatinform>|$1|g;

	s/(\S)&apos;/$1’/g; # smart quotes
	s/&apos;/‘/g;
	s/&quot;(?=[\w'])/“/g;
	s/&quot;/”/g;  # or $_[0] =~ s/(?<!\s)"/&#8221;/g; $_[0] =~ s/(\A|\s)"/$1&#8220;/g;
	
	# italicize certain abbreviations
	for my $abbrev (@italicize_abbrevs) {
		s|\b($abbrev)\b|<i>$1</i>|g;
	}
	### specify STEDTU here?

	s/&lt;-+&gt;/⟷/g; # convert arrows
	s/< /< /g; # no-break space after "comes from" sign
	
	s/^<p>//; # get rid of surround <p> tags.
	s|</p>$||;
	return $_;
}

sub notes_for_rn : StartRunmode {
	my $self = shift;
	my $rn = $self->param('rn');
	
	my $INTERNAL_NOTES = $self->param('userprivs') >= 16;
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I'" unless $INTERNAL_NOTES;

	my $notes = $self->dbh->selectall_arrayref("SELECT xmlnote FROM notes WHERE rn=? $internal_note_search", undef, $rn);
	my @notes;
	my (@dummy, $dummy);
	for (@$notes) {
		 my $xml = decode_utf8($_->[0]);
		 push @notes, xml2html($xml, $self->dbh, \@dummy, \$dummy);
	}
	return join '<p>', @notes;
}

# return an etymon page with notes, reflexes, etc.
sub etymon : Runmode {
	my $self = shift;
	my $tag = $self->param('tag');
	
	my $INTERNAL_NOTES = $self->param('userprivs') >= 16;
	my $internal_note_search = '';
	$internal_note_search = "AND notetype != 'I' AND notetype != 'O'" unless $INTERNAL_NOTES;
	my (@etyma, @footnotes);
	my $footnote_index = 1;
	my $etyma_for_tag = $self->dbh->selectall_arrayref(
qq#SELECT e.tag, e.printseq, e.protoform, e.protogloss, e.plg, e.hptbid, e.tag=e.supertag AS is_main
	FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag
	WHERE e.supertag=?
	ORDER BY is_main DESC, e.plgord#, undef, $tag);
	if (!@$etyma_for_tag) {
		# if it failed the first time, this is probably a mesoroot.
		# get the mesoroot's supertag and try one more time
		($tag) = $self->dbh->selectrow_array("SELECT supertag FROM etyma WHERE tag=?", undef, $tag);
		$etyma_for_tag = $self->dbh->selectall_arrayref(
qq#SELECT e.tag, e.printseq, e.protoform, e.protogloss, e.plg, e.hptbid, e.tag=e.supertag AS is_main
	FROM `etyma` AS `e` JOIN `etyma` AS `super` ON e.supertag = super.tag
	WHERE e.supertag=?
	ORDER BY is_main DESC, e.plgord#, undef, $tag);
	}
	if (!@$etyma_for_tag) { die "no etymon with tag #$tag" }

	foreach (@$etyma_for_tag) {
		my %e; # hash of infos to be added to @etyma
		push @etyma, \%e;
	
		# heading stuff
		@e{qw/tag printseq protoform protogloss plg hptbid is_main/}
			= map {decode_utf8($_)} @$_;
		$e{plg} = $e{plg} eq 'PTB' ? '' : "$e{plg}";
	
		$e{protoform} =~ s/⪤} +/⪤} */g;
		$e{protoform} =~ s/OR +/OR */g;
		$e{protoform} =~ s/\\textasciitilde\\ +/~ */g;
		$e{protoform} =~ s/ = +/ = */g;
		$e{protoform} = '*' . $e{protoform};
		
		# etymon notes
		$e{notes} = [];
		my $seen_hptb; # don't generate an HPTB reference if there's a custom HPTB note already
		foreach (@{$self->dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
				. "WHERE tag=$e{tag} AND notetype != 'F' ORDER BY ord")}) {
			my $notetype = $_->[0];
			next if $notetype eq 'I' && !$INTERNAL_NOTES; # skip internal notes if we're publishing
			$seen_hptb = 1 if $notetype eq 'H';
			push @{$e{notes}}, {type=>$notetype,
				text=>xml2html(decode_utf8($_->[1]), $self->dbh, \@footnotes, \$footnote_index)};
		}
		if ($e{hptbid} && !$seen_hptb) {
			my $text = "See <i>HPTB</i> ";
			my @refs = split /,/, $e{hptbid};
			my @strings;
			for my $id (@refs) {
				my ($pform, $plg, $pages) =
					$self->dbh->selectrow_array("SELECT protoform, plg, pages FROM hptb WHERE hptbid=?", undef, $id);
				$pform = decode_utf8($pform);
				my $p = ($pages =~ /,/ ? "pp" : "p");
				push @strings, ($plg eq 'PTB' ? '' : "$plg ") . "<b>$pform</b>, $p. $pages";
			}
			$text .= join('; ', @strings);
			$text .= '.';
			push @{$e{notes}}, {type=>'H', text=>$text};
		}
	
	
		# do entries
		my $sql = <<EndOfSQL;
SELECT DISTINCT lexicon.rn, lexicon.analysis, languagenames.lgid, lexicon.reflex, lexicon.gloss, lexicon.gfn,
	languagenames.language, languagegroups.grpid, languagegroups.grpno, languagegroups.grp,
	languagenames.srcabbr, lexicon.srcid, languagegroups.ord, notes.rn
FROM lexicon LEFT JOIN notes ON notes.rn=lexicon.rn, languagenames, languagegroups, lx_et_hash
WHERE (lx_et_hash.tag = $e{tag}
AND lx_et_hash.rn=lexicon.rn
AND languagenames.lgid=lexicon.lgid
AND languagenames.grpid=languagegroups.grpid
)
ORDER BY languagegroups.ord, languagenames.lgsort, reflex, languagenames.srcabbr, lexicon.srcid
EndOfSQL
		my $recs = $self->dbh->selectall_arrayref($sql);
		if (@$recs) { # skip if no records
			for my $rec (@$recs) {
				$_ = decode_utf8($_) foreach @$rec;
				if ($rec->[-1]) { # if there are any notes...
					# only select notes which are generic (empty id) OR those that have specifically been marked as belonging to this etymon/reflex combination
					my @results = @{$self->dbh->selectall_arrayref("SELECT notetype, xmlnote FROM notes "
							. "WHERE notes.rn=? AND (`id`=$e{tag} OR `id`='') $internal_note_search ORDER BY ord",
							undef, $rec->[0])};
					$rec->[-1] = '';
					# NB: these are footnotes, and they don't have footnotes inside them!
					foreach (@results) {
						my ($notetype, $note) = @$_;
						$note = xml2html(decode_utf8($note), $self->dbh, \@footnotes, \$footnote_index);
						if ($notetype eq 'I') {
							$note =~ s/^/[Internal] <i>/;
							$note =~ s|$|</i>|;
						}
						$note =~ s/^/[Source note] / if $notetype eq 'O';
						push @footnotes, $note;
						$rec->[-1] .= ' ' . $footnote_index++;
					}
				}
			}
			$e{records} = $recs;
		}
	
		# Chinese comparanda
		$e{comparanda} = [];
		my @comparanda = @{$self->dbh->selectcol_arrayref("SELECT xmlnote FROM notes WHERE tag=$e{tag} AND notetype = 'F'")};
		for my $note (@comparanda) {
			$note = decode_utf8($note);
#			$note =~ s/(Karlgren|Li|Baxter): /\\hfill $1: /g;
			$note =~ s/ Citations:/\n\nCitations:/g;
			$note =~ s/ Correspondences:/\n\nCorrespondences:/g;
#			$note =~ s/(\[ZJH\])/\\hfill $1/g;
#			$note =~ s/(\[JAM\])/\\hfill $1/g;
			push @{$e{comparanda}}, xml2html(decode_utf8($note), $self->dbh, \@footnotes, \$footnote_index);
		}
	}

	return $self->tt_process("etymon.tt", {
		etyma    => \@etyma,
		fields => ['lexicon.rn', 'lexicon.analysis', 'languagenames.lgid', 'lexicon.reflex', 'lexicon.gloss', 'lexicon.gfn',
			'languagenames.language', 'languagegroups.grpid', 'languagegroups.grpno', 'languagegroups.grp',
			'languagenames.srcabbr', 'lexicon.srcid', 'languagegroups.ord', 'notes.rn'],
		footnotes => \@footnotes,
		internal_notes => $INTERNAL_NOTES,
	});
	# @etyma : [
	# 	{
	# 		tag,
	# 		printseq,
	# 		...
	# 		notes : [],
	# 		fields: [],
	# 		records: [],
	# 		comparanda: [],
	# 	}
	# ]
}


1;
