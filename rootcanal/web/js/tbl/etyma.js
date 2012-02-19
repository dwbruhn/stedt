setup['etyma']['num_recs'].transform = function (v,key,rec,n) {
	 return (v!=='0' || rec[n+1]!=='0' || rec[n+2]!=='0')
		? '<a href="' + baseRef + 'edit/lexicon?analysis=' + key + '" target="stedt_lexicon">' + v + '&nbsp;r\'s</a>'
		: v + '&nbsp;r\'s';
};
