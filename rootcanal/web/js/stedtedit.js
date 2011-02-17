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

function show_advanced_search(tbl) {
	var result_table = $(tbl + '_resulttable');
	var t = new Element('table');
	t.width = '100%';
	t.style.tableLayout = 'fixed';
	var r = t.insertRow(-1);
	$A(result_table.tHead.rows[0].cells).each(function (th) {
		var c = new Element('td');
		c.width = th.getWidth();
		var box = new Element('input', {id:th.id});
		box.setStyle({width:'100%'});
		c.appendChild(box);
		r.appendChild(c);
	});
	result_table.parentNode.insertBefore(t, result_table);
}

document.observe("dom:loaded", stedtedit);
