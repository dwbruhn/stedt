setup['lexicon']['lexicon.srcid'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + rec[n-1] + '">' + rec[n-1] + '</a>'
		+ (v ? ':&thinsp;' + v : '');
};

setup['lexicon']['num_notes'] = {
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
