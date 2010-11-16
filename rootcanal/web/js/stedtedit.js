// this function will be called when loaded (see last line)
function stedtedit() {
function create_searchfn(divname) { return function (e) {
new Ajax.Request(baseRef + 'search/' + divname, {
parameters: { s : $F(divname + '_searchinput') },
onSuccess: ajax_make_table,
onFailure: function (transport){ alert('Error: ' + transport.responseText); },
onComplete: function (transport){ $(divname + '_search').enable(); }
});
$(divname + '_search').disable(); // prevent accidental multiple submit. reversed by onComplete, above.
return false;
}}

$('etyma_search').onsubmit = create_searchfn('etyma');
$('lexicon_search').onsubmit = create_searchfn('lexicon');
$('simple_search').onsubmit = create_searchfn('simple');

new Draggable('dragger', { constraint: 'vertical', change: function (draggableInstance) {
	var d = $('dragger');
	var mytop = d.offsetTop;
	var ettop = $('etyma').offsetTop;
	$('etyma').setStyle({height:(mytop - ettop) + 'px'});
	$('lexicon').setStyle({top:(d.offsetTop + d.offsetHeight) + 'px'});
},
snap : function (x, y, d) {
	var min = $('etyma').offsetTop + 75;
	var max = $('lexicon').offsetTop + $('lexicon').offsetHeight - 100;
	if (y < min) y = min;
	if (y > max) y = max;
	return [x, y];
}
});

$('simple_searchinput').focus();
}

document.observe("dom:loaded", stedtedit);
