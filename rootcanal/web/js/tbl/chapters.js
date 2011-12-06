
setup.chapters = {
    _key: 'chapters.id',
    'chapters.id': {
	label: 'id',
	noedit: true,
	hide: true,
	size: 50
    },
    'chapters.chapter' : {
	label: 'chapter',
	noedit: false,
	size: 80,
	transform : function (v) {
	    return '<a href="' + baseRef + 'edit/chapter?chapters.chapter=' + v + '" target="stedt_chapters">' + v + '</a>';
	}
    },
    'chapters.chaptertitle' : {
	label: 'chaptertitle',
	noedit: false,
	hide: false,
	size: 150
    },
    'chapters.v' : {
	label: 'v',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.f' : {
	label: 'f',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.c' : {
	label: 'c',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.s1' : {
	label: 's1',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.s2' : {
	label: 's2',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.s3' : {
	label: 's3',
	noedit: false,
	hide: false,
	size: 50
    },
    'chapters.semcat' : {
	label: 'semcat',
	noedit: false,
	hide: false,
	size: 120
    },
    'chapters.old_chapter' : {
	label: 'old chapter',
	noedit: false,
	hide: false,
	size: 100
    },
    'chapters.old_subchapter' : {
	label: 'old subchapter',
	noedit: false,
	hide: false,
	size: 100
    },
};
