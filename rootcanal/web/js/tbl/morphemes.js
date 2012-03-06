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
    'morphemes.prefx' : {
	label: 'pfx',
	noedit: true,
	hide: false,
	size: 30
    },
    'morphemes.initial' : {
	label: 'I',
	noedit: true,
	hide: false,
	size: 30
    },
    'morphemes.rhyme' : {
	label: 'R',
	noedit: true,
	hide: false,
	size: 30
    },
    'morphemes.tone' : {
	label: 'T',
	noedit: true,
	hide: false,
	size: 30
    },
    'analysis' : {
	label: 'analysis1',
//	noedit: !(stedtuserprivs & 8),
	noedit: true,
	hide: !(stedtuserprivs & 1),
	size: 80,
	transform: function (v) {
	    return v.replace(/, */g,', ');
	}
    },
    'user_an' : {
	label: 'analysis2',
	size: 80,
	noedit: true,
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
	noedit: true,
	noedit: !(stedtuserprivs & 1),
	size: 160
    },
    'morphemes.morpheme' : {
	label: 'morpheme',
	noedit: true,
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
	size: 180
    },
//    'languagegroups.grpid' : {
//	label: 'grpid',
//	noedit: true,
//	hide: true
//    },
    'morphemes.grpno' : {
	label: 'group',
	noedit: true,
	size: 120
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
	hide: false
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
	noedit: true,
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
