function color_workflow_status(v) {
    var color ;
    if (v.match('\\*')) {
	color = '#fff2b3';
    } else if (v.match('\\$')) {
	color = '#b3ffb3';
    } else if (v.match('\\#')) {
	color = '#ffb3b3';
    } else if (v.match('\\%')) {
	color = '#ccbcff';
    }
    return color ? '<span style="background-color : ' + color + '">' + v + '</span>' : v;
}

setup.projects = {
    _key: 'projects.id',
    'projects.id': {
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.querylex' : {
	label: 'glosses',
	noedit: false,
	size: 180,
	transform : function (v) {
	    return '<a href="' + baseRef + 'edit/lexicon?lexicon.gloss=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
    },
   'projects.creator' : {
	label: 'creator',
	noedit: false,
	hide: false,
       size: 50,
       transform : function (v) {
	   return color_workflow_status (v);
       }
    },
    'projects.tagger' : {
	label: 'tagger',
	noedit: false,
	hide: false,
	size: 50,
	transform : function (v) {
	   return color_workflow_status (v);
       }
    },
    'projects.proofreader' : {
	label: 'proofrdr',
	noedit: false,
	hide: false,
	size: 50,
	transform : function (v) {
	   return color_workflow_status (v);
       }
    },
    'projects.approver' : {
	label: 'approver',
	noedit: false,
	hide: false,
	size: 50,
	transform : function (v) {
	   return color_workflow_status (v);
       }
    },
    'projects.published' : {
	label: 'published',
	noedit: false,
	hide: false,
	size: 50,
	transform : function (v) {
	   return color_workflow_status (v);
       }
    },
    'projects.create_date' : {
	label: 'creation date',
	noedit: true,
	hide: true,
	size: 100
    },
    'projects.tag_date' : {
	label: 'tagged',
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.proofread_date' : {
	label: 'proofed',
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.approve_date' : {
	label: 'approved',
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.publish_date' : {
	label: 'published',
	noedit: true,
	hide: true,
	size: 50
    },
    'pct' : {
	label: 'pct',
	noedit: true,
	size: 30
    },
    'projects.count_reflexes' : {
	label: 'reflexes',
	noedit: true,
	size: 30
    },
    'projects.count_etyma' : {
	label: 'etyma',
	noedit: true,
	size: 30
    },
    'projects.tagged_reflexes' : {
	label: 'tagged',
	noedit: true,
	size: 30
    },
    'projects.status' : {
	label: 'status',
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.workflow' : {
	label: 'workflow',
	noedit: true,
	hide: true,
	size: 50
    },
    'projects.subproject' : {
	label: 'subproject',
	size: 80,
	transform : function (v) {
	    return '<a href="' + baseRef + 'edit/etyma?etyma.protogloss=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
    },
    'projects.project' : {
	label: 'project',
	size: 60
    },
    'users.username' : {
	label: 'user',
	size: 80,
	hide: true,
	noedit: true
    }
};
