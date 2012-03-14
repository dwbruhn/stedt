var my_dragger;
var horz_dragger = function () {
	return new Draggable('dragger', { constraint: 'vertical', change: function (draggableInstance) {
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
};
var vert_dragger = function () {
	return new Draggable('dragger', { constraint: 'horizontal', change: function (draggableInstance) {
			var d = $('dragger');
			var mytop = d.offsetLeft;
			var ettop = $('etyma').offsetLeft;
			$('etyma').setStyle({width:(mytop - ettop) + 'px'});
			$('lexicon').setStyle({left:(d.offsetLeft + d.offsetWidth) + 'px'});
		},
		snap : function (x, y, d) {
			var min = 150;
			var max = $('lexicon').offsetLeft + $('lexicon').offsetWidth - 200;
			if (x < min) x = min;
			if (x > max) x = max;
			return [x, y];
		}
	});
};

// this function will be called when loaded (see last line)
function stedt_simplesearch_init() {
	$w('etyma lexicon').each(function (t) {
		if ($(t + '_resulttable'))
			TableKit.Raw.init(t + '_resulttable', t, setup[t], stedtuserprivs&1 ? baseRef+'update' : 0);
	});
	var do_search = function (e) {
		var tbl = e.findElement().id.sub('_search', '');
		new Ajax.Request(baseRef + 'search/ajax', {
			method: 'get',
			parameters: { tbl : tbl, s : $F(tbl + '_searchinput'), lg : $F(tbl + '_searchlg'), lggrp : $F(tbl + '_searchlggrp'), f : $F(tbl + '_searchform')},
			onSuccess: ajax_make_table,
			onFailure: function (transport){ alert('Error: ' + transport.responseText); },
			onComplete: function (transport){ $(tbl + '_search').enable(); }
		});
		$(tbl + '_search').getElements().invoke('blur');
		$(tbl + '_search').disable(); // prevent accidental multiple submit. reversed by onComplete, above.
		return false;
	};
	
	$('etyma_search').onsubmit = do_search;
	$('lexicon_search').onsubmit = do_search;
	my_dragger = horz_dragger();
	Ajax.Responders.register({
		onCreate: function() { $('spinner').show() },
		onComplete: function() { if (0 == Ajax.activeRequestCount) $('spinner' ).hide() }
	});
};

function vert_tog() {
	var t = $('etyma_resulttable'), fields = [];
	$('etyma').setAttribute('style',''); // for some reason removeAttribute doesn't seem to work so well...
	$('lexicon').setAttribute('style','');
	$('dragger').setAttribute('style','');
	$('info').hide();
	my_dragger.destroy();
	if ($('etyma').hasClassName('vert')) {
		$('etyma').removeClassName('vert');
		$('lexicon').removeClassName('vert');
		$('dragger').removeClassName('vert');
		if (t) {
			$A(t.tHead.rows[0].cells).each(function (c, i) {
				setup.etyma[c.id].hide = setup.etyma[c.id].old_hide;
				if (!setup.etyma[c.id].hide) c.style.display = '';
				fields.push(c.id);
			});
			$A(t.tBodies[0].rows).each(function (row) {
				$A(row.cells).each(function (c,i) {
					if (!setup.etyma[fields[i]].hide) c.style.display = '';
				});
			});
		}
		my_dragger = horz_dragger();
	} else {
		$('etyma').addClassName('vert');
		$('lexicon').addClassName('vert');
		$('dragger').addClassName('vert');
		if (t) {
			$A(t.tHead.rows[0].cells).each(function (c, i) {
				if (!setup.etyma[c.id].vert_show) c.style.display = 'none';
				setup.etyma[c.id].old_hide = setup.etyma[c.id].hide;
				setup.etyma[c.id].hide = !setup.etyma[c.id].vert_show;
				fields.push(c.id);
			});
			$A(t.tBodies[0].rows).each(function (row) {
				$A(row.cells).each(function (c,i) {
					if (!setup.etyma[fields[i]].vert_show) c.style.display = 'none';
				});
			});
		}
		my_dragger = vert_dragger();
	}
	return false;
};

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
	return false;
};

document.observe("dom:loaded", stedt_simplesearch_init);
