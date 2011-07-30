var SEQ = Class.create({
initialize: function () {	
	$('all_tags').on('change', '.paf-btn', function (e) {this.repaf(e.findElement())}.bind(this));
	this.init_sort_all();
},

init_sort_all: function () {
	var all_c = $$(".etymon-container,.uncontainer");
	all_c.each(function (x) {this.init_sort(x, all_c)}.bind(this));
	Sortable.create('all_tags', {
		tag:'div', only:'allofam', scroll:window,
		onUpdate:this.reseq.bind(this)
	});
},

// init a single container for sorting. optionally pass in the list of the other containers for efficiency.
init_sort: function (c,cc) {
	if (!cc) { cc = $$(".etymon-container,.uncontainer") }
	Sortable.create(c.id, {
		tag:'div', only:'etymon', scroll:window,
		containment:cc,
		dropOnEmpty:true,
		onUpdate:this.handle_etymon_move.bind(this)
	});
},

// cleanup method to be called once after handle_etymon_move
cleanup : function () {
	this.reseq();
	if (this.cleanup_new) {
		this.init_sort_all(); // call this after reseq() since reseq might change some classes
	}
	this.cleanup_scheduled = false;
},

// re-letter all the "etymon" divs, given a container; also re-init_sort
reletter: function (c) {
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
},

reseq: function () {
	$$('.allofam').each(function (a,i) {
		a.down('.seq-num').innerHTML = i+1;
		this.reletter(a.down('.etymon-container'));
	}.bind(this));
},

handle_etymon_move: function (c) {
	var etymon, a, old_a, do_cleanup = false;
	if (c.hasClassName('uncontainer')) { // if 'fake' container, make a new one and reseq
		old_a = c.up('.allofam'); // may be null if it's actually .allofam-noseq
		etymon = c.down('.etymon');

		// create a new allofam div
		a = $('all_tags').firstDescendant().clone(true);
		a.id = 'fam_' + (++last_fam_seq);
		a.down('.uncontainer').id = 'deallofam_' + last_fam_seq;
		a.down('.uncontainer').update(); // clear this out since it might still have a copy of the moved item

		// put the etymon in it
		c = a.down('.etymon-container');
		c.id = 'allofams_' + last_fam_seq;
		c.update().insert(etymon);

		// put it in the right place
		if (old_a) {
			old_a.insert({after:a});
			if (!old_a.down('.etymon-container').firstChild) { old_a.remove(); } // see note under "else", below
		} else { $('all_tags').insert({top:a}) }
		this.cleanup_new = true;
		do_cleanup = true;
	} else if (!c.firstChild) { // if empty container, delete it and reseq
		// but make sure that (1) it's not .allofam-noseq, and
		// (2) it really is empty (i.e., prevent the case where you drag the last etymon into the fake container below it and the whole thing gets deleted!
		// easier to handle it here, delaying the remove() call until later [see above], than to prevent the user from dragging it there in the first place.)
		if (c.up('.allofam') && !c.up('.allofam').down('.uncontainer').firstChild) {
			c.up('.allofam').remove();
			do_cleanup = true;
		}
	} else {
		this.reletter(c);
		this.init_sort(c);
	}
	if (do_cleanup && !this.cleanup_scheduled) {
		this.cleanup.bind(this).defer();
		this.cleanup_scheduled = true;
	}
},

// checkbox for PAF
// clicking on a PAF btn to "on" automatically turns off the other one(s)
// the other one(s) get shifted down and everything gets re-lettered
// move new one to top
repaf: function (x) {
	var c = x.up('.etymon-container');
	var was_paf = x.parentNode.className === 'paf';
	$$('#' + c.id + ' .paf').each(function (e) {
		e.down('.paf-btn').checked = false;
		e.className = 'etymon';
	});
	if (!was_paf) {
		x.checked = true;
		x = x.up('.etymon');
		x.className = 'paf';
		x.down('.seq-str').innerHTML = x.up('.allofam').down('.seq-num').innerHTML;
		c.insert({top:x});
	}
	this.reletter(c);
	this.init_sort(c); // PAFs can't be sorted
},
});

new SEQ();

// send list of lists of tag nums (starting with the "n/a" set).
// first item of tagnum list is 'P' if first tagnum is PAF.
var self_serialize = function () {
	if (!confirm("Are you sure you want to save the current sequencing?")) return false;
	var list = $$('.allofam-noseq, .allofam').map(function (a) {
		var tags = Selector.findChildElements(a, ['.etymon','.paf']).map(function (e) {
			return e.id.sub(/\D+/,'');
		});
		if (a.down('.paf')) { tags.unshift('P'); }
		return tags;
	});
	$('seqs_input').setValue(Object.toJSON(list));
	return true;
};
