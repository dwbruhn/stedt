setup.languagenames = {
	_key: 'languagenames.lgid',
	'languagenames.lgid': {
		noedit: true,
		hide: !(stedtuserprivs & 1),
		size:40
	},
	'num_recs': {
		noedit: true,
		size:40,
		transform : function (v, key) {
			return '<a href="' + baseRef + 'edit/lexicon?lexicon.lgid=' + key + '" target="stedt_lexicon">' + v + ' r\'s</a>';
		}
	},
	'languagenames.srcabbr': {
		size:70,
 		transform : function (v) {
			return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + v + '" target="edit_src">' + v + '</a>';
		}
	},
	'languagenames.lgabbr': {
		size:100
	},
	'languagenames.lgcode': {
		size:40
	},
	'languagenames.silcode': {
		size:40
	},
	'languagenames.language': {
		size:120
	},
	'languagenames.lgsort': {
		size:90
	},
	'languagenames.notes': {
		size:60
	},
	'languagenames.srcofdata': {
		size:50
	},
	'languagegroups.grpno': {
		noedit: true,
		hide: true,
		size:70
	},
	'languagegroups.grp': {
		noedit: true,
		hide: true,
		size:110
	},
	'languagenames.grpid': {
		label: 'group',
		noedit: true,
		size:120,
		transform : function (v, key, rec, i) {
			return rec[i-2] + ' - ' + rec[i-1];
		}
	}
};
