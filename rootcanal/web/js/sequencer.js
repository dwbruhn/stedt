// re-letter all the "etymon" divs, given a container
var reletter = function (c) {
	if (c.up('.allofam-noseq')) {
		$$('#' + c.id + ' .etymon').each(function (e) {
			e.down('.seq-str').innerHTML = '0';
		});
		return;
	}
	var seq = c.up('.allofam').down('.seq-num').innerHTML;
	var etyma = Selector.findChildElements(c, ['.etymon','.paf']);
	if (etyma.length > 1) {
		// reletter just the non-pafs
		$$('#' + c.id + ' .etymon').each(function (e,i) {
			e.down('.seq-str').innerHTML = seq + String.fromCharCode(97+i);
			e.down('.paf-btn').disabled = false;
		});
	} else if (etyma.length) {
		// if there's only one, make sure it's not a PAF anymore
		if (c.down('.paf')) c.down('.paf').className = 'etymon';
		c.down('.seq-str').innerHTML = seq;
		c.down('.paf-btn').checked = false;
		c.down('.paf-btn').disabled = true;
	}
};

var reseq = function () {
	$$('.allofam').each(function (a,i) {
		a.down('.seq-num').innerHTML = i+1;
		reletter(a.down('.etymon-container'));
	});
};

var handle_etymon_move = function (c) {
	var etymon, a, old_a, all_containers;
	if (c.hasClassName('uncontainer')) { // if 'fake' container, make a new one and reseq
		old_a = c.up('.allofam'); // may be null if it's actually .allofam-noseq
		etymon = c.down('.etymon');

		// create a new allofam div
		a = $('all_tags').firstDescendant().clone(true);
		a.id = 'fam_' + (++last_fam_seq);
		a.down('.uncontainer').id = 'deallofam_' + last_fam_seq;
		a.down('.uncontainer').innerHTML = ''; // clear this out since it might still have a copy of the moved item

		c = a.down('.etymon-container');
		c.id = 'allofams_' + last_fam_seq;
		c.innerHTML = '';
		c.insert(etymon);

		if (old_a) {
			old_a.insert({after:a});
			if (!old_a.down('.etymon-container').firstChild) { old_a.remove(); } // see note under "else", below
		} else {
			$('all_tags').insert({top:a}); // special case for inserting at the top of the list
		}
		reseq();
		
		// re-init sorting for everything since we added a new container
		all_containers = $$(".etymon-container,.uncontainer");
		all_containers.each(function (x) {
			Sortable.create(x.id, {tag:'div', only:'etymon', scroll:window,
				containment:all_containers,
				dropOnEmpty:true,
				onUpdate:handle_etymon_move
			});
		});
		Sortable.create('all_tags', {tag:'div', only:'allofam', scroll:window, onUpdate:reseq});
	} else if (!c.firstChild) { // if empty container, delete it and reseq
		// but make sure that (1) it's not .allofam-noseq, and
		// (2) it really is empty (i.e., prevent the case where you drag the last etymon into the fake container below it and the whole thing gets deleted!
		// easier to handle it here, delaying the remove() call until later [see above], than to prevent the user from dragging it there in the first place.)
		if (c.up('.allofam') && !c.up('.allofam').down('.uncontainer').firstChild) {
			c.up('.allofam').remove();
			reseq();
		}
	} else {
		reletter(c);
		Sortable.create(c.id, {tag:'div', only:'etymon', scroll:window,
			containment:$$(".etymon-container,.uncontainer"),
			dropOnEmpty:true,
			onUpdate:handle_etymon_move
		});
	}
};

// checkbox for PAF
// clicking on a PAF btn to "on" automatically turns off the other one(s)
// the other one(s) get shifted down and everything gets re-lettered
// move new one to top
var repaf = function (x) {
	var container = x.up('.etymon-container');
	var was_paf = x.parentNode.className === 'paf';
	var etyma = $$('#' + container.id + ' .paf');
	etyma.each(function (e,i) {
		e.down('.paf-btn').checked = false;
		e.className = 'etymon';
	});
	if (!was_paf) {
		x.checked = true;
		x = x.up('.etymon');
		x.className = 'paf';
		x.down('.seq-str').innerHTML = x.up('.allofam').down('.seq-num').innerHTML;
		container.insert({top:x});
	}
	reletter(container);
	// re-init the sorting for this container only
	Sortable.create(container.id, {tag:'div', only:'etymon', scroll:window,
		containment:$$(".etymon-container,.uncontainer"),
		dropOnEmpty:true,
		onUpdate:handle_etymon_move
	}); // PAFs can't be sorted
};

// send list of lists, starting from 0
// each item is list of tag nums
// first item is 'P' if first item is PAF
var self_serialize = function () {
	if (!confirm("Are you sure you want to save the current sequencing?")) return false;
	var list = $$('.allofam-noseq, .allofam').map(function (a) {
		var list = Selector.findChildElements(a, ['.etymon','.paf']).map(function (e) {
			return e.id.sub(/\D+/,'');
		});
		if (a.down('.paf')) { list.unshift('P'); }
		return list;
	});
	$('seqs_input').setValue(Object.toJSON(list));
	return true;
};


// initialization stuff
$$('.paf-btn').each(function (x) {
	x.observe('change', function (e) {
		repaf(e.findElement('input'));
		e.stop();
	});
});
var all_containers = $$(".etymon-container,.uncontainer");
all_containers.each(function (x) {
	Sortable.create(x.id, {tag:'div', only:'etymon', scroll:window,
		containment:all_containers,
		dropOnEmpty:true,
		onUpdate:handle_etymon_move
	});
});
Sortable.create('all_tags', {tag:'div', only:'allofam', scroll:window, onUpdate:reseq});
