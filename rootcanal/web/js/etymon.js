setup['lexicon']['lexicon.rn'].transform = function (v) {
	if (stedtuserprivs & 1) {
		return '<a href="' + baseRef + 'edit/lexicon' + '?lexicon.rn=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
	else return v;
};
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

// put in section headings for language groups (and subgroup approval button)
var lgord2grp = {"90":"9. Sinitic","63":"6.1.2. Loloish","21":"2.1. Tibeto-Kanauri","70":"7. Karenic","102":"X.2. Unknown/Unevaluated","80":"8. Bai","26":"2.1.5. Dhimal","17":"1.6. Mru","18":"1.7. Bodo-Garo = Barish","30":"2.3.2. Kiranti","16":"1.5. Mikir","100":"X. Other Languages","27":"2.2. Newar","25":"2.1.4. Tamangic","28":"2.3. Mahakiranti","40":"4. Jingpho-Nung-Luish","61":"6.1. Lolo-Burmese","14":"1.3.1. Northern Naga","20":"2. Himalayish","24":"2.1.3. Lepcha","10":"1.1.1. Tani","35":"3. Tangut-Qiang","11":"1.1.2. Deng","22":"2.1.1. Western Himalayish","42":"4.2. Nungic","0":"0. Sino-Tibetan","13":"1.3. \"Naga\"","23":"2.1.2. Bodic","29":"2.3.1. Kham-Magar-Chepang-Sunwar","50":"5. Tujia","64":"6.2. Naxi","36":"3.1. Tangut","9":"1.1. North Assam","12":"1.2. Kuki-Chin","41":"4.1. Jingpho","15":"1.4. Meithei","8":"1. Kamarupan","38":"3.3. rGyalrongic","60":"6. Lolo-Burmese-Naxi","101":"X.1. Non-TB","37":"3.2. Qiangic","19":"1.8. Chairel","43":"4.3. Luish","62":"6.1.1. Burmish"};
var grp_confirm = function (tag, grp_name) {
	return confirm('Are you sure you want to approve tagging by ' + stedt_other_username
		+ ' for tag #' + tag + ' in subgroup ' + grp_name + '?');
};
for (var i = 1; i < num_tables; i++) {
	var tbody = $('lexicon' + i).tBodies[0];
	var table_tag = $('lexicon' + i).getAttribute("tag");
	var lastord = -1;
	var ord_index = $('languagegroups.ord').previousSiblings().length; // counting backwards, i.e., "tbody.rows[0].cells.length - 3", doesn't work because there may or may not be a HIST column depending on if the user is logged in
	// var grp_index = $('languagegroups.grp').previousSiblings().length; // get location of cell containing grp name
	var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
	$A(tbody.rows).each(function (row, j) {
		var ord = row.cells[ord_index].innerHTML;
		if (lastord != ord) {
			var newrow = new Element('tr', {'class':'lggroup'});
			row.insert({before:newrow});
			var cell1 = newrow.insertCell(-1);
			var cell2 = newrow.insertCell(-1);
			cell1.colSpan = 3;
			cell2.colSpan = visiblecols - 3;
			cell1.innerHTML = lgord2grp[ord];
			cell2.className = "noedit"; // prevent tablekit from trying to edit this cell. Not needed for cell1 since it's in the rn column
			if (stedtuserprivs & 1) {
				// insert html form for approving this subgroup only
				var grp_name = lgord2grp[ord].replace(/"/g,'&quot;').replace(/^[\d.]+ /, '');
				cell2.innerHTML = '<form action="' + baseRef + 'notes/accept" method="post" '
				+ 'onsubmit="return grp_confirm(' + table_tag +  ',\'' + grp_name + '\')"><input name="tag" value="' + table_tag
				+ '" type="hidden"><input name="uid" value="' + uid2 + '" type="hidden"><input name="ord" value="'
				+ ord + '" type="hidden"><input type="submit" value="Accept ' + grp_name + ' only"></form>';
			}
			lastord = ord;
		}
	});
}
