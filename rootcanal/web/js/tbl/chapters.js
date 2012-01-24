
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
	    return '<a href="' + baseRef + 'edit/glosswords?glosswords.semkey=' + v + '" target="edit_glosswords">' + v + '</a>';
	}
    },
    'chapters.chaptertitle' : {
	label: 'title',
	noedit: false,
	hide: false,
	size: 200
    },
    'chapters.chapterabbr' : {
	label: 'other glosses',
	noedit: false,
	hide: false,
	size: 120
    },
    'chapters.v' : {
	label: 'vol',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.f' : {
	label: 'fasc',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.c' : {
	label: 'chap',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.s1' : {
	label: 's1',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.s2' : {
	label: 's2',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.s3' : {
	label: 's3',
	noedit: false,
	hide: false,
	size: 20
    },
    'chapters.semcat' : {
	label: 'semcat',
	noedit: false,
	hide: false,
	size: 80
    },
    'chapters.old_chapter' : {
	label: 'old chapter',
	noedit: false,
	hide: false,
	size: 60
    },
    'chapters.old_subchapter' : {
	label: 'old subchapter',
	noedit: false,
	hide: false,
	size: 80
    }
};
