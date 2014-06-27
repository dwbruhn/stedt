setup.notes = {
	_key: 'notes.noteid',
	'notes.noteid': {
		noedit: true,
//		hide: !(stedtuserprivs & 1),
		size: 20
	},
	'notes.spec': {
		label: 'location',
		noedit: true,
		size: 20,
		transform: function (v) {
			switch(v) {	// note that we can only get away w/o break statements because of the returns
				case 'E':
					return 'Etyma';
				case 'L':
					return 'Lexicon';
				case 'C':
					return 'Chapter';
				case 'S':
					return 'Source';
				default:
					return v;			
			}
		}
	},
	'notes.notetype': {
		label: 'type',
		noedit: true,
		size: 20,
		transform: function (v) {
			switch(v) {	// note that we can only get away w/o break statements because of the returns
				case 'T':
					return 'Text';
				case 'I':
					return 'Internal';
				case 'N':
					return 'New';
				case 'O':
					return 'Orig/Src';
				case 'G':
					return 'Graphics';
				case 'F':
					return 'Final';
				case 'H':
					return 'HPTB';
				default:
					return v;			
			}
		}
	},
	'notes.rn': {
		label: 'rn',
		noedit: true,
		size: 15,
		transform: function (v) {
			if (v != "0") {
				return '<a href="' + baseRef + 'edit/lexicon?lexicon.rn=' + v + '" target="stedt_lexicon">' + v + '</a>';
			} else return '';
		}
	},
      	_postprocess: function (tbl) {
      		tbl.on('mouseover', 'a.elink', et_info_popup);
      		tbl.on('mouseout', 'a.elink', et_info_popup);
      	},
	'notes.tag' : {
		label: 'tag',
		noedit: true,
		size: 20,
		transform: function (v,k,rec,n) {
			if (v != "0") {
				return '<a href="' + baseRef + 'etymon/' + v + '" target="stedt_etymon" class="elink t_' +v+'">' + v + '</a>';
			} else return '';
			
		}
      	},
      	'notes.id': {
		label: 'id',
		noedit: true,
		size: 25,
		transform: function (v,k,rec,n) {
			if (v==='' || v==='0') return v;	// return id if id is blank or zero
			switch(rec[n-4]) {	// interpretation of value in id depends on spec, which is in rec[n-4]
				case 'L':	// lexicon note, so id contains tag num
					return 'tag: <a href="' + baseRef + 'etymon/' + v + '" target="stedt_etymon" class="elink t_' +v+'">' + v + '</a>';
				case 'S':	// source note, so id contains srcabbr
					return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + v + '" target="edit_src">' + v + '</a>';
				case 'C':	// chapter note, so id contains chapter
					return 'chap: <a href="' + baseRef + 'chap/' + v + '" target="stedt_chapters">' + v + '</a>';
				case 'E':	// if spec=E and id has a value, then id=grpid for subgroup note; get grpno from next column
					return 'grpid: <a href="' + baseRef + 'etymon/' + rec[n-1] + '#' + rec[n+1] + '" target="stedt_etymon">' + v + '</a>';
				default:
					return v;			
			}
		}
	},
	'grpno': {
		label: 'grpno',
		hide: true,
		noedit: true
	},
	'notes.ord': {
		label: 'order',
		noedit: true,
		size: 15
	},
      	'notes.xmlnote' : {
		noedit: true,
      		label: 'text',
      		size: 200,
      		transform: function (v,k,rec,n) {
			return rec[n]; // eventually this needs to show result of xml2html (how to access that function?)
		}
      	},
      	'users.username' : {
      		label: 'owner',
      		size: 20,
      		noedit: true
      	},
      	'notes.uid' : { // this is just a search field
      		label: 'owner'
      	}
};
