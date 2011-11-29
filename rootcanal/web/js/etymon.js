setup['lexicon']['languagegroups.grpno'].hide = true;
setup['lexicon']['notes.rn'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		var addlink = '<a href="#" class="lexadd">[+]</a>';
		if (v === '0') return (stedtuserprivs & 1) ? addlink : '';
		var a = v.match(/\d+/g).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '">' + s + '</a>';
		});
		a.push(addlink);
		return a.join(' ');
	}
};
if (stedt_other_username) {
	setup['lexicon']['user_an']['label'] = stedt_other_username + '\'s analysis';
	setup['lexicon']['user_an']['transform'] = function (v) {
		if (!v) return '';
		var s = v.replace(/, */g,', ');
		// hilite this gray if it doesn't contain the etyma we're concerned with on this page
		var to_be_approved = v.split(',').any(function (t) { return skipped_roots[t]; });
		if (to_be_approved) return s;
		return '<div class="approve-ignore">' + s + '</div>';
	};
	setup['lexicon']['analysis']['transform'] = function (v,key,rec,n) {
		var s = v.replace(/, */g,', ');
		// hilite this magenta if it would get clobbered on approval, i.e.
		// if it's not empty, the two cols are different, and the user_an is not gray
		if (v && v !== rec[n+1] && rec[n+1].split(',').any(function (t) { return skipped_roots[t]; })) {
			return '<div class="approve-replacing">' + s + '</div>';
		}
		return s;
	};
}
for (var i = 1; i < num_tables; i++) {
	TableKit.Raw.init('lexicon' + i, 'lexicon', setup['lexicon'], stedtuserprivs&1 ? baseRef+'update' : 0);
	TableKit.Rows.stripe('lexicon' + i);
	TableKit.tables['lexicon' + i].editAjaxExtraParams += '&uid2=' + uid2;
}

// put in section headings for language groups
var lgord2grp = {0:'0. Sino-Tibetan', 10:'1. Kamarupan', 11:'1.1 North Assam', 12:'1.2 Kuki-Chin',
14:'1.3 Naga', 15:'1.4 Meithei', 16:'1.5 Mikir', 17:'1.6 Mru', 18:'1.7 Bodo-Garo = Barish',
19:'1.8 Chairel', 20:'2. Himalayish', 21:'2.1 Tibeto-Kanauri', 22:'2.1.1 Western Himalayish',
23:'2.1.2 Bodic', 24:'2.1.3 Lepcha', 25:'2.1.4 Tamangic', 26:'2.1.5 Dhimal', 27:'2.2 Newar',
28:'2.3. Mahakiranti', 29:'2.3.1 Kham-Magar-Chepang-Sunwar', 30:'2.3.2 Kiranti', 35:'3. Tangut-Qiang',
36:'3.1 Tangut', 37:'3.2 Qiangic', 38:'3.3 rGyalrongic', 40:'4. Jingpho-Nung-Luish', 41:'4.1 Jingpho',
42:'4.2 Nungic', 43:'4.3 Luish', 50:'5. Tujia', 60:'6. Lolo-Burmese', 61:'6.1 Burmish', 62:'6.2 Loloish',
63:'6.3 Naxi', 64:'6.4 Jinuo', 70:'7. Karenic', 80:'8. Bai', 90:'9. Sinitic', 100:'X. Non-TB'};
for (var i = 1; i < num_tables; i++) {
	var tbody = $('lexicon' + i).tBodies[0];
	var lastord = -1;
	var ord_index = tbody.rows[0].cells.length - 2;
	var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
	$A(tbody.rows).each(function (row, j) {
		var ord = row.cells[ord_index].innerHTML;
		if (lastord != ord) {
			var newrow = new Element('tr', {'class':'lggroup'});
			row.insert({before:newrow});
			var cell = newrow.insertCell(-1);
			cell.colSpan = visiblecols;
			cell.innerHTML = lgord2grp[ord];
			lastord = ord;
		}
	});
}
