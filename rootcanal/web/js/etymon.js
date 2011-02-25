setup['lexicon']['languagegroups.grpno'].hide = true;
setup['lexicon']['notes.rn'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		if (v === '') return stedtuserprivs ? '<a href="#" class="lexadd">[+]</a>' : '';
		var a = $A(v.match(/\d+/g)).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '">' + s + '</a>';
		});
		return a.join(' ');
	}
};
for (var i = 1; i < num_tables; i++) {
	TableKit.Raw.init('lexicon' + i, 'lexicon', stedtuserprivs >= 16 ? '[% self_url %]/update' : null);
	TableKit.Rows.stripe('lexicon' + i);
}

// put in section headings for language groups
var lgord2grp = {0:'0. Sino-Tibetan', 10:'1. Kamarupan', 11:'1.1 North Assam', 12:'1.2 Kuki-Chin',
14:'1.3 Naga', 15:'1.4 Meithei', 16:'1.5 Mikir', 17:'1.6 Mru', 18:'1.7 Bodo-Garo = Barish',
19:'1.8 Chairel', 20:'2. Himalayish', 21:'2.1 Tibeto-Kanauri', 22:'2.1.1 Western Himalayish',
23:'2.1.2 Bodic', 24:'2.1.3 Lepcha', 25:'2.1.4 Tamangic', 26:'2.1.5 Dhimal', 27:'2.2 Newar',
28:'2.3. Mahakiranti', 29:'2.3.1 Kham-Magar-Chepang-Sunwar', 30:'2.3.2 Kiranti', 35:'3. Tangut-Qiang',
36:'3.1 Tangut', 37:'3.2 Qiangic', 38:'3.3 rGyalrongic', 40:'4. Jingpho-Nung-Luish', 41:'4.1 Jingpho',
42:'4.2 Nungic', 43:'4.3 Luish', 50:'5. Tujia', 60:'6. Lolo-Burmese', 61:'6.1 Burmish', 62:'6.2 Loloish',
63:'6.3 Naxi', 64:'6.4 Jinuo', 70:'7. Karenic', 80:'8. Bai', 90:'9. Sinitic', 100:'X. Non-TB'};
for (var i = 1; i < num_tables; i++) {
	var tbody = $('lexicon' + i).tBodies[0];
	var lastord = -1;
	var ord_index = tbody.rows[0].cells.length - 2;
	var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
	$A(tbody.rows).each(function (row, j) {
		var ord = row.cells[ord_index].innerHTML;
		if (lastord != ord) {
			var newrow = new Element('tr', {'class':'lggroup'});
			row.insert({before:newrow});
			var cell = newrow.insertCell(-1);
			cell.colSpan = visiblecols;
			cell.innerHTML = lgord2grp[ord];
			lastord = ord;
		}
	});
}

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
		e.stop();
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
$$('.noteform').each(function (f) {init_note_form(f)});

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
		} else {
			Sortable.destroy(container.id);
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
		f.ord.value = +$$('#allnotes' + id + ' .reord').last().down('form').ord.value+1;
	} else if (spec === 'F') {
		container = $('allcomparanda' + id);
		f.ord.value = +$$('#allcomparanda' + id + ' .reord').last().down('form').ord.value+1;
		spec = 'E';
	} else if (spec === 'C') {
		// container = ;
		f.ord.value = 1; // *** need to change this when chapter browser is in place
	} else {
		f.ord.value = 1;
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
					$A(result).each(function (text) {
						var n = ++footnote_counter;
						var elem = new Element('p', {'class':'footnote fnote-' + id,
							id:'foot' + n});
						elem.innerHTML = '<a href="#toof' + n + '">^ ' + n + '.</a> '
							+ text;
						f.up('body').insert(elem);
					});
					// enable the sort box if there are two or more sortable items
					if ($$('#' + container.id + ' .reord').length > 1)
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
		e.stop();
	};
};

$$('.lexadd').each(function (a) {
	var id = $(a).up('tr').id;
	a.onclick = function (e) {
		showaddform('L',id);
		e.stop();
	};
});
