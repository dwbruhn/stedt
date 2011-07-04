setup['lexicon']['lexicon.srcid'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + rec[n-1] + '">' + rec[n-1] + '</a>'
		+ (v ? ':&thinsp;' + v : '');
};

setup['lexicon']['num_notes'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		if (v === '0') return (stedtuserprivs & 1) ? '<a href="#" class="lexadd">[+]</a>' : '';
		var a = $A(v.match(/\d+/g)).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '">' + s + '</a>';
		});
		return a.join(' ');
	}
};
