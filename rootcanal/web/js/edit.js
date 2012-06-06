var scrollEnd = function() {
	if (document.body.scrollHeight) { window.scrollTo(0, document.body.scrollHeight); 
	} else if (screen.height) { window.scrollTo(0, screen.height); } // IE5 
}
var add_record = function () { new Ajax.Request(baseRef + 'add/' + tablename, {
	parameters: $('add_form').serialize(true),
    onSuccess: function (transport,json){
		var response = transport.responseText || "ERROR: no response text";
		var rec = response.evalJSON();
		var t = $(tablename + '_resulttable');
		var row = t.insertRow(-1);
		var tinfo = TableKit.tables[t.id];
		var rowid = json.id;
		row.id = tinfo.rawPrefix + '_' + rowid;
		var rawData = tinfo.raw.data;
		var head_cells = TableKit.getHeaderCells(t);
		rec.each(function (v,i) {
			var xform = setup[tablename][head_cells[i].id].transform;
			var cell = row.insertCell(-1);
			if (setup[tablename][head_cells[i].id].hide) cell.style.display = 'none';
			if (v) {
				cell.innerHTML = xform	? xform(v.escapeHTML(), rowid, rec, i)
										: v.escapeHTML();
			}
		});
		rawData[rowid] = rec;
		TableKit.reload();
		scrollEnd();
		if (setup[tablename]._postprocess_onadd) setup[tablename]._postprocess_onadd($(row));
		$$('.add_reset').each(function(i) {if (i.name !== 'lexicon.lgid') i.value = ''});
    },
    onFailure: function(transport){ alert('Error: ' + transport.responseText) }
})};
var clear_form = function (f) {
	$A(f.elements).each(function (x) {
		if (x.type !== undefined) switch (x.type.toLowerCase()) {
			case "text":
			case "password":
			case "textarea":
			case "hidden":
				x.value = "";
				break;
			case "radio":
			case "checkbox":
				if (x.checked) x.checked = false;
				break;
			case "select-one":
			case "select-multi":
				x.selectedIndex = 0;
				break;
			default:
				break;
		}
	});
};
$('search_form').observe('keydown', function (e) {
	var currentlySelected;
	if (e.keyCode === Event.KEY_ESC) {
		e.stop();
		currentlySelected = e.findElement();
		currentlySelected.blur(); // FireFox has problems setting x.value if x is currently selected, so we use this workaround
		if (this.select('input:not(:button,:submit,:reset),select').any(Form.Element.getValue)) {
			clear_form(this);
		} else {
			this.reset();
		}
		currentlySelected.focus();
	}
});
$('search_form').observe('submit', function (e) {
// 	e.stop();
// 	document.location = '?' + Form.serializeElements(this.select('input:not(:button,:submit,:reset),select').findAll(Form.Element.getValue));
//	remember in js the string "0" evaluates to true, so this works for any non-empty form input/select element.
	var empty_elems = this.select('input:not(:button,:submit,:reset),select').reject(Form.Element.getValue);
	empty_elems.push(this.select(':submit')[0]);
	empty_elems.invoke('disable'); // disable unused form elements (temporarily) for cleaner URLs
	window.setTimeout(function () {
		empty_elems.invoke('enable');
	}, 0); // defer this until after the submit happens
});
