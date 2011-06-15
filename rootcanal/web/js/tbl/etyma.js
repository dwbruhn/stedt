setup['etyma']['num_recs'].transform = function (v,key) {
	 return v != 0
		? '<a href="' + baseRef + 'edit/lexicon?analysis=' + key + '">' + v + '&nbsp;r\'s</a>'
		: v + '&nbsp;r\'s';
};
