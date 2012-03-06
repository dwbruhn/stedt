
setup.soundlaws = {
    _key: 'soundlaws.id',
    'soundlaws.id': {
	noedit: true,
	hide: true,
	size: 40
    },
   'soundlaws.corrid' : {
       label: 'corrid',
       noedit: false,
       hide: false,
       transform : function (v, key, rec, n) {
	   var slot = {'I': 'initial', 'R' : 'rhyme', 'T': 'tone'}[rec[2]];
	   return '<a href="' + baseRef + 'edit/morphemes?morphemes.' + slot + '=' + rec[5] +'&morphemes.lgid=' + rec[9] + '" target="edit_etyma">' + v + '</a>';
       },
       size: 40
    },
    'soundlaws.slot' : {
	label: 'slot',
	noedit: false,
	hide: false,
	size: 40
    },
    'soundlaws.protolg' : {
	label: 'protolg',
	noedit: false,
	hide: false,
	size: 60
    },
    'soundlaws.ancestor' : {
	label: 'ancestor',
	noedit: false,
	hide: false,
	size: 50
    },
    'soundlaws.outcome' : {
	label: 'outcome',
	noedit: false,
	hide: false,
	size: 50
    },
    'soundlaws.language' : {
	label: 'language',
	noedit: false,
	hide: false,
	size: 100
    },
    'soundlaws.context' : {
	label: 'context',
	noedit: false,
	hide: false,
	size: 50
    },
    'soundlaws.n' : {
	label: 'N',
	noedit: true,
	hide: false,
	size: 30
    },
    'soundlaws.srcabbr' : {
	label: 'source',
	noedit: true,
	hide: true,
	size: 30
    },
    'soundlaws.srcid' : {
	label: 'srcid',
	noedit: true,
	hide: true,
	size: 30
    },
    'soundlaws.lgid' : {
	label: 'lgid',
	noedit: true,
	size: 60
    }
};
