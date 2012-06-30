setup['etyma']['num_recs'].transform = function (v,key,rec,n) {
	 return (v!=='0' || rec[n+1]!=='0' || rec[n+2]!=='0')
		? '<a href="' + baseRef + 'edit/lexicon?analysis=' + key + '" target="stedt_lexicon">' + v + '&nbsp;r\'s</a>'
		: v + '&nbsp;r\'s';
};
setup['etyma']['etyma.grpid'].noedit = false;
setup['etyma']['etyma.status'].transform = function (v) {
	if (v.toUpperCase() === 'DELETE') return v;
	return v + '<input value="Del" type="button" class="del_btn">';
};
setup['etyma']['etyma.status'].size = 40;
var do_delete_check = function (tag) {
	new Ajax.Request(baseRef + 'tags/delete_check0', {
		parameters: {tag: tag},
		onSuccess: function(transport) {
			var t = transport.responseText;
			if (t) {
				alert("Can't delete #" + tag + ":\n\n" + t);
				return;
			}
			window.open(baseRef + 'tags/delete_check?tag=' + tag, 'delete_check_popup', 'width=800,height=800');
		},
		onFailure: function(transport) {
			alert(transport.responseText);
		}
	});
};
