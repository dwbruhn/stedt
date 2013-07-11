setup.glosswords = {
    _key: 'glosswords.id',
    'glosswords.id': {
	label: 'id',
	noedit: true,
	hide: true,
	size: 50
    },
    'glosswords.word' : {
	label: 'gloss word',
	noedit: !(stedtuserprivs & 8),
	size: 80,
	transform : function (v) {
	    return '<a href="' + baseRef + 'edit/lexicon?lexicon.gloss=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
    },
    'glosswords.semkey' : {
	label: 'semkey',
	noedit: !(stedtuserprivs & 8),
	hide: false,
	size: 200,
	transform : function (v) {
	    return '<a href="' + baseRef + 'edit/glosswords?glosswords.semkey=' + v + '">' + v + '</a>';
	}
    },
    'glosswords.subcat' : {
	label: 'old categorization',
	noedit: !(stedtuserprivs & 8),
	hide: false,
	size: 120
    },
    'chapters.chaptertitle' : {
	label: 'vfc heading',
	noedit: !(stedtuserprivs & 8),
	hide: false,
	size: 120
    },
    'num_recs' : {
	label: 'words w this semkey',
	noedit: true,
	hide: false,
	size: 50,
	transform : function (v, key, rec, n) {
		return '<a href="' + baseRef + 'edit/lexicon?lexicon.semkey=' + rec[n-3] + '" target="stedt_lexicon">' + v + '</a>';	
	}
    },
    'glosswords.semcat' : {
	label: 'semcat',
	noedit: !(stedtuserprivs & 8),
	hide: false,
	size: 80
    }
};
