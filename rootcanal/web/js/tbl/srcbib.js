setup.srcbib = {
	_key: 'srcbib.srcabbr',
	'srcbib.srcabbr': {
		noedit: true,
		size:70,
		transform : function (v) {
			return '<a href="' + baseRef + 'source/' + v + '" target="stedt_src">' + v + '</a>';
		}
	},
	'num_lgs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/languagenames?languagenames.srcabbr=' + key + '" target="stedt_lgs">' + v + ' lg' + (v == 1 ? '' : 's') + '</a>';
		}
	},
	'num_recs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/lexicon?languagenames.srcabbr=' + key + '" target="stedt_lexicon">' + v + ' r\'s</a>';
		}
	},
	'srcbib.citation': {
		size:100
	},
	'srcbib.author': {
		size:120
	},
	'srcbib.year': {
		size:50
	},
	'srcbib.title': {
		size:120
	},
	'srcbib.imprint': {
		size:100
	},
	'srcbib.status': {
		size:100,
		transform : function (v, key) {
			v = v.replace(/\n\n+/, '<p>');
			v = v.replace(/\n/, '<br>');
			return v;
		}
	},
	'srcbib.notes': {
		size:100
	},
	'srcbib.todo': {
		size:100
	},
	'srcbib.format': {
		size:100
	}
};
