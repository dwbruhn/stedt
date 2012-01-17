setup.morphemes = {
    _key: 'morphemes.id',
    'morphemes.id' : {
	label: 'id',
	noedit: true,
	hide: true,
	size: 70
    },
    'morphemes.rn' : {
	label: 'rn',
	noedit: true,
	hide: true,
	size: 70
    },
    'analysis' : {
	label: 'analysis1',
	noedit: !(stedtuserprivs & 8),
	hide: !(stedtuserprivs & 1),
	size: 80,
	transform: function (v) {
	    return v.replace(/, */g,', ');
	}
    },
    'user_an' : {
	label: 'analysis2',
	size: 80,
	transform: function (v) {
	    return v.replace(/, */g,', ');
	}
    },
//    'languagenames.lgid' : {
//	label:'lgid',
//	noedit: true,
//	hide: true
//    },
    'morphemes.reflex' : {
	label: 'form',
	noedit: !(stedtuserprivs & 1),
	size: 160,
	transform: function (v,key,rec) {
	    if (!v) return '';
	    var analysis = rec[1] || ''; // might be NULL from the SQL query
	    var an2, t2;
	    if (setup.morphemes._an2) {
		an2 = rec[2] || '';
		t2 = an2.split(',');
	    } else {
		t2 = [];
	    }
	    var tags = analysis.split(',');
	    var result = SYLSTATION.syllabify(v.unescapeHTML());
	    // since the transform receives escaped HTML, but SylStation
	    // treats semicolons as delims, we have to unescape (e.g.
	    // things like "&amp;" back to "&") before passing to SylStation
				// and re-escape below when putting together the HTML string.
	    var i, l = result[0].length, a = result[2], s, delim, link_tag, syl_class;
				for (i=0; i<l; ++i) {
				    s = result[0][i];
				    delim = result[1][i] || '&thinsp;'
				    link_tag = '';
				    syl_class = '';
				    // figure out what class to assign (so it shows up with the right color)
				    if (tags[i] && t2[i]) {
					syl_class = 't_' + tags[i]; // put this in for div#info purposes
					if (tags[i]===t2[i]) {
					    // if stedt and user tags match, use the user's style
					    syl_class += ' u' + t2[i];
					    link_tag = stedttagger ? (skipped_roots[t2[i]] ? '' : t2[i]) : '';
					} else {
					    // otherwise mark this syllable as a conflict
					    syl_class += ' t_' + t2[i] + ' approve-conflict';
					    link_tag = stedttagger ? t2[i] : '';
					}
				    } else if (tags[i]) { // if only one or the other of the columns is defined, then simply mark it as such.
					syl_class = 't_' + tags[i] + ' r' + tags[i];
					link_tag = stedttagger ? (skipped_roots[tags[i]] ? '' : tags[i]) : '';
				    } else if (t2[i]) {
					syl_class = 't_' + t2[i] + ' u' + t2[i];
					link_tag = stedttagger ? (skipped_roots[t2[i]] ? '' : t2[i]) : '';
				    }
				    a += parseInt(link_tag,10)
					? '<a href="' + baseRef + 'etymon/' + link_tag + '#' + link_tag + '" target="stedt_etymon"'
					+ '" class="elink ' + syl_class + '">'
					+ s.escapeHTML() + '</a>' + delim
					: '<span class="' + syl_class + '">' + s.escapeHTML() + '</span>' + delim;
				}
	    return a;
	}
    },
    'morphemes.morpheme' : {
	label: 'morpheme',
	noedit: !(stedtuserprivs & 16),
	size: 80
    },
    'morphemes' : {
	label: 'morpheme(s)',
	noedit: true,
	size: 80
    },
    'reflexes' : {
	label: 'reflexes(s)',
	noedit: true,
	size: 180
    },
    'morphemes.gloss' : {
	label: 'gloss',
	noedit: !(stedtuserprivs & 16),
	size: 160
    },
    'glosses' : {
	label: 'gloss(es)',
	noedit: !(stedtuserprivs & 16),
	size: 160
    },
    'morphemes.gfn' : {
	label: 'gfn',
	noedit: !(stedtuserprivs & 16),
	size: 30
		},
    'morphemes.language' : {
	label: 'language',
	noedit: true,
	size: 180,
	transform : function (v, key, rec, n) {
	    return '<a href="' + baseRef + 'group/' + rec[n+1] + '/' + rec[n-1] + '" target="stedt_grps">' + v + '</a>';
	}
    },
    'languages' : {
	label: 'language(s)',
	noedit: true,
	size: 180,
    },
//    'languagegroups.grpid' : {
//	label: 'grpid',
//	noedit: true,
//	hide: true
//    },
    'morphemes.grpno' : {
	label: 'group',
	noedit: true,
	size: 120,
//	transform : function (v, key, rec, n) {
//	    return v + ' - ' + rec[n+1];
//	}
    },
    'morphemes.grp' : {
	label: 'grp',
	noedit: true,
	hide: true
    },
    'morphemes.srcabbr' : {
	label: 'source(s)',
	noedit: true,
	size: 80,
	hide: true
    },
    'morphemes.srcid' : {
	label: 'source',
	size: 140,
	noedit: true,
	hide: true
    },
    'morphemes.semcat' : {
	label: 'semcat'
    },
    'morphemes.semkey' : {
	label: 'semkey',
	noedit: false,
	size: 40,
	hide: false
    },
    'num_notes' : {
	label: 'notes',
	noedit: true,
	hide: true,
	size: 200,
	transform: function (v) {
	    if (v == 0) return '';
	    return '<a href="#" class="note_retriever">'
		+ v + '&nbsp;note' + (v == 1 ? '' : 's')
		+ '</a>';
	}
    },
    'morphemes.status' : {
	label:'status',
	noedit: false,
	size: 20,
	hide: false
    }
//    },
//    'languagegroups.ord' : {
//	noedit: true,
//	size: 40,
//	hide: true
//    }
};
