setup['lexicon']['lexicon.srcid'].transform = function (v, k, rec, n) {
	return '<a href="' + baseRef + 'edit/srcbib?srcbib.srcabbr=' + rec[n-1] + '">' + rec[n-1] + '</a>'
		+ (v ? ':&thinsp;' + v : '');
};
