setup.hptb = {
	_key: 'hptb.hptbid',
	'hptb.hptbid': {
		label: 'id',
		noedit: true,
		size:4
	},
	'hptb.protoform': {
		label: 'protoform',
		noedit: true,
		size:15
	},
	'hptb.protogloss': {
		label: 'protogloss',
		noedit: true,
		size:20
	},
	'hptb.plg': {
		label: 'pLg',
		size:4
	},
	'tags' : {
		label: 'tags',
		size:4
	},
	'hptb.mainpage': {
		label: 'main page',
		size:4
	},
	'hptb.pages': {
		label: 'HPTB pages',
		size:20
	},
	'hptb.tags': {
		label: 'guessed tag #\'s',
		size:20,
		transform: function (v) {
				return v.replace(/, */g,', ');
			}
	},
	'hptb.semclass1': {
		label: 'semclass1',
		size:20
	},
	'hptb.semclass2': {
		label: 'semclass2',
		size:20
	}
};
