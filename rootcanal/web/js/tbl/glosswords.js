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
	noedit: false,
	size: 80,
	transform : function (v) {
	    return '<a target="lexicon" href="' + baseRef + 'edit/lexicon?lexicon.gloss=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
    },
    'glosswords.semkey' : {
	label: 'semkey',
	noedit: false,
	hide: false,
	size: 200,
	transform : function (v) {
	    return '<a target="lexicon" href="' + baseRef + 'edit/glosswords?glosswords.semkey=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
    },
    'glosswords.subcat' : {
	label: 'old categorization',
	noedit: false,
	hide: false,
	size: 120
    },
    'chapters.chaptertitle' : {
	label: 'vfc heading',
	noedit: false,
	hide: false,
	size: 120
    },
    'num_recs' : {
	label: 'words w this semkey',
	noedit: false,
	hide: false,
	size: 50
    },
    'glosswords.semcat' : {
	label: 'semcat',
	noedit: false,
	hide: false,
	size: 80
    }
};
