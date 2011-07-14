setup['lexicon']['languagegroups.grpno'].hide = true;
setup['lexicon']['notes.rn'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		var addlink = '<a href="#" class="lexadd">[+]</a>';
		if (v === '0') return (stedtuserprivs & 1) ? addlink : '';
		var a = $A(v.match(/\d+/g)).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '">' + s + '</a>';
		});
		a.push(addlink);
		return a.join(' ');
	}
};
if (stedt_other_username) {
	setup['lexicon']['user_an']['label'] = stedt_other_username + '\'s analysis';
	setup['lexicon']['lexicon.reflex']['transform'] = function (v,key,rec) {
			if (!v) return '';
			var analysis = rec[1] || ''; // might be NULL from the SQL query
			var an2 = rec[2] || '';
			var tags = analysis.split(',');
			var t2 = an2.split(',');
			var result = SYLSTATION.syllabify(v);
			var a = result[0].map(function (s,i) {
				var delim = result[1][i] || '&thinsp;';
				var makelink = !skipped_roots[tags[i]];
				return (parseInt(tags[i], 10) && makelink)
					? '<a href="' + baseRef + 'etymon/' + tags[i] + '" target="stedt_etymon"'
						+ ' class="r' + tags[i] + ' u' + t2[i] + '">'
						+ s + '</a>'  + delim
					: '<span class="r' + tags[i] + ' u' + t2[i] + '">' + s + '</span>' + delim;
			});
			return a.join('');
	};
}
for (var i = 1; i < num_tables; i++) {
	TableKit.Raw.init('lexicon' + i, 'lexicon', (stedtuserprivs & 1) ? (baseRef+'update') : null);
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
