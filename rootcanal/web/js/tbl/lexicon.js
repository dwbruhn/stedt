setup['lexicon']['languagenames.language'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/languagenames?languagenames.language=' +  v + '"'
		+ ' title="' + rec[n+2] + ' - ' + rec[n+3].replace(/"/g,'&quot;') + '"'
		+ ' target="stedt_lgs">' + v + '</a>';
};

setup['lexicon']['lexicon.srcid'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + rec[n-1] + '" target="edit_src">' + rec[n-1] + '</a>'
		+ (v ? ':&thinsp;' + v : '');
};

setup['lexicon']['num_notes'] = {
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

setup['lexicon']['analysis'].label =
	$("uid1").options[$("uid1").selectedIndex].text + '\'s analysis';

setup['lexicon']['user_an'].label =
	$("uid2").options[$("uid2").selectedIndex].text  + '\'s analysis';
