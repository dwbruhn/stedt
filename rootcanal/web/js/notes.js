// note saving and deleting via AJAX
function init_note_form(f) {
	var id = f.noteid.value;
	f.onsubmit = function (e) {
		new Ajax.Request(baseRef + 'notes/save', {
			parameters: f.serialize(),
			onSuccess: function (t,json) {
				// skip if there were no changes
				if (f.mod.value === json.lastmod) return;
				var result = t.responseText.split("\r");
				var note = result.shift();
				note = note.replace(/"#foot(\d+)" id="toof\1"><sup>\1/g, function (s, n1) {
					var n =+n1+footnote_counter;
					return '"#foot' + n + '" id="toof' + n + '"><sup>' + n;
				});
				$('preview' + id).innerHTML = note;
				f.mod.value = json.lastmod;
				$('lastmod' + id).innerHTML = json.lastmod;
				$$('.fnote-' + id).invoke('remove');
				$A(result).each(function (text) {
					var n = ++footnote_counter;
					var elem = new Element('p', {'class':'footnote fnote-' + id,
						id:'foot' + n});
					elem.innerHTML = '<a href="#toof' + n + '">^ ' + n + '.</a> '
						+ text;
					f.up('body').insert(elem);
				});
			},
			onFailure: function(t) {
				alert(t.responseText);
			}
		});
		Event.stop(e);
	};
	f.delete_btn.onclick = function () {
		if (!confirm('Are you sure you want to delete the selected records?'))
			return;
		new Ajax.Request(baseRef + 'notes/delete', {
			parameters: {noteid:id,mod:f.mod.value},
			onSuccess: function (t,json) {
				$$('.fnote-' + id).invoke('remove');
				var x = $('reorddiv_' + id);
				if (x.hasClassName('lexnote')) {// remove the footnotemark if there is one
					var mark = x.down('a').id.replace(/^foot/,'toof');
					$(mark).remove();
				}
				x.remove();
			},
			onFailure: function(t) {
				alert(t.responseText);
			}
		});
	};
};
$$('.noteform').each(init_note_form);

// note reordering
$$('.reordcheckbox').each(function (c) {
	var container = $(c).up('.container');
	c.onclick = function (e) {
		if (c.checked) {
			Sortable.create(container.id, {tag:'div', only:'reord', scroll:window, onUpdate:function () {
				new Ajax.Request(baseRef + 'notes/reorder', {
					parameters: {ids:Sortable.serialize(container.id,{name:'z'})},
					onFailure: function(t){ alert('Error: ' + t.responseText) }
				});
			}});
			container.select('form').invoke('hide');
		} else {
			Sortable.destroy(container.id);
			container.select('form').invoke('show');
		}
	};
});

// adding new notes
function showaddform (spec, id) { // C, E, L; F for comparanda (special handling of notetype)
	var labels = {O:'Orig/src-DON\'T MODIFY', T:'Text', I:'Internal',
					N:'New', G:'Graphic', F:'Final', H:'HPTB'};
	var f = $('addnoteform');
	var container = null; // id of the enclosing div for sorting
	// constrain notetypes; set ord
	var types = spec === 'L' ? ['N','I','O'] : spec === 'F' ? ['F'] :
		spec === 'E' ? ['T','I','H','N'] : ['T','I','N','G','F'];
	// set id (and spec F -> E)
	if (spec === 'E') {
		container = $('allnotes' + id);
	} else if (spec === 'F') {
		container = $('allcomparanda' + id);
		spec = 'E';
	} else if (spec === 'C') {
		container = $('allnotes');
	} else { // lexicon note
		f.ord.value = 1;
	}
	if (container) {
		var existing_notes = container.select('.reord');
		if (existing_notes.size()) {
			f.ord.value = +existing_notes.last().down('form').ord.value+1;
		} else { // there are no existing notes; the first note's ord should be 1
			f.ord.value = 1;
		}
	}
	// set spec, id
	f.spec.value = spec;
	f.id.value = id;
	f.fn_counter.value = footnote_counter;
	var menu = f.notetype.options;
	for (var i=0; i<types.length; i++) {
		menu[i] = new Option(labels[types[i]],types[i]);
	}
	menu[0].selected = 'selected'; // select the first item
	f.show();
	f.xmlnote.focus();
	f.onsubmit = function (e) {
		new Ajax.Request(baseRef + 'notes/add', {
			parameters: f.serialize(),
			onSuccess: function (t,json) {
				var result = t.responseText.split("\r");
				var note = result.shift();
				if (container) {
					// insert the HTML in the right place
					container.insert(note);
					// insert footnotes at the end, if necessary
					// *** the code to adjust the footnote numbers is kind of ugly;
					// the prettier way would be to send the current footnote number
					// to the server, then increment footnote_counter by the
					// number of text blocks in result.
					$A(result).each(function (text) {
						var n = ++footnote_counter;
						var elem = new Element('p', {'class':'footnote fnote-' + id,
							id:'foot' + n});
						elem.innerHTML = '<a href="#toof' + n + '">^ ' + n + '.</a> '
							+ text;
						f.up('body').insert(elem);
					});
					// enable the sort box if there are two or more sortable items
					if (container.select('.reord').length > 1)
						container.down('.reordcheckbox').enable();
				} else {
					// if it's a lex note, stick it in at the bottom, and add the footnotemark in the table
					f.up('body').insert(note);
					++footnote_counter;
					var cell = $(id).childElements().last();
					var celltext = cell.innerHTML;
					cell.innerHTML = celltext + ' <a href="#foot' + footnote_counter + '" id="toof' + footnote_counter + '">' + footnote_counter + '</a>';
				}
				// attach javascript
				init_note_form($('reorddiv_' + json.id).down('.noteform'));
				f.xmlnote.value = ''; // reset the textarea
				f.hide();
			},
			onFailure: function(t) {
				alert(t.responseText);
			}
		});
		Event.stop(e);
	};
	return false;
};

// show/hide the editing form
function show_edit (n) {
	$('form' + n).toggle();
	return false;
};
