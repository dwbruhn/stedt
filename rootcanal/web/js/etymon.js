setup['lexicon']['lexicon.rn'].transform = function (v) {
	if (stedtuserprivs & 1) {
		return '<a href="' + baseRef + 'edit/lexicon' + '?lexicon.rn=' + v + '" target="stedt_lexicon">' + v + '</a>';
	}
	else return v;
};
setup['lexicon']['languagegroups.grpno'].hide = true;
setup['lexicon']['notes.rn'] = {
	label: 'notes',
	noedit: true,
	size: 80,
	transform : function (v) {
		var addlink = '<a href="#" class="lexadd">[+]</a>';
		if (v === '0') return (stedtuserprivs & 1) ? addlink : '';
		var a = v.match(/\d+/g).map(function (s) {
			return '<a href="#foot' + s + '" id="toof' + s + '">' + s + '</a>';
		});
		a.push(addlink);
		return a.join(' ');
	}
};
if (stedt_other_username) {
	setup['lexicon']['user_an']['label'] = stedt_other_username + '\'s analysis';
	setup['lexicon']['user_an']['transform'] = function (v) {
		if (!v) return '';
		var s = v.replace(/, */g,', ');
		// hilite this gray if it doesn't contain the etyma we're concerned with on this page
		var to_be_approved = v.split(',').any(function (t) { return skipped_roots[t]; });
		if (to_be_approved) return s;
		return '<div class="approve-ignore">' + s + '</div>';
	};
	setup['lexicon']['analysis']['transform'] = function (v,key,rec,n) {
		var s = v.replace(/, */g,', ');
		// hilite this magenta if it would get clobbered on approval, i.e.
		// if it's not empty, the two cols are different, and the user_an is not gray
		if (v && v !== rec[n+1] && rec[n+1].split(',').any(function (t) { return skipped_roots[t]; })) {
			return '<div class="approve-replacing">' + s + '</div>';
		}
		return s;
	};
}
for (var i = 1; i < num_tables; i++) {
	TableKit.Raw.init('lexicon' + i, 'lexicon', setup['lexicon'], stedtuserprivs&1 ? baseRef+'update' : 0);
	TableKit.Rows.stripe('lexicon' + i);
	TableKit.tables['lexicon' + i].editAjaxExtraParams += '&uid2=' + uid2;
}

// prompt user to get new tag for migrating reflexes
function migrate_prompt(tag, grp_name, grp_num)
{
	var new_tag = prompt('Subgroup: ' + grp_name + '\nCurrent tag: #' + tag + '\nEnter new tag: ');

	// make sure user entered integer
	if (new_tag == null || new_tag == '')
	{
		// just ignore (they pressed 'cancel')
	}
	else if((parseFloat(new_tag) !== parseInt(new_tag)) || isNaN(new_tag))
	{
		alert('\"' + new_tag + '\" is not a valid tag number!');
	}
	else if(new_tag == tag)
	{
		alert('Reflexes are already tagged as #' + tag);
	}
	else
	{
		// create temporary hidden form to submit data to migration subroutine
		var temp_form = new Element('form', {method: 'post', action: baseRef + 'tags/migrate_tag'});
		temp_form.insert(new Element('input', {name: 'tag', value: tag, type: 'hidden'}));
		temp_form.insert(new Element('input', {name: 'grpno', value: grp_num, type: 'hidden'}));
		temp_form.insert(new Element('input', {name: 'new_tag', value: new_tag, type: 'hidden'}));
		$(document.body).insert(temp_form);
		temp_form.submit();		
	}	 
}

// put in section headings for language groups (and subgroup approval button)
var grp_confirm = function (tag, grp_name) {
	return confirm('Are you sure you want to approve tagging by ' + stedt_other_username
		+ ' for tag #' + tag + ' in subgroup ' + grp_name + '?');
};

var grpno_index = $('languagegroups.grpno').cellIndex;
	// Counting backwards doesn't work (i.e., "tbody.rows[0].cells.length - 3")
	// because there may or may not be a HIST column depending on if the user is logged in.
	// Note that having multiple <TH> elements with the same id value ("languagegroups.grpid", etc.)
	// is technically incorrect HTML, but in this case seems to have no ill effect.
for (var i = 1; i < num_tables; i++) {
	var tbody = $('lexicon' + i).tBodies[0];
	var table_tag = $('lexicon' + i).getAttribute("tag"); // access a custom HTML attribute
	var lastgrpno = '';
	var visiblecols = $A(tbody.rows[0].cells).findAll(function (c) {return $(c).visible();}).length;
	$A(tbody.rows).each(function (row, j) {
		var grpno = row.cells[grpno_index].innerHTML;
		var grp = row.cells[grpno_index+1].innerHTML;
		if (lastgrpno !== grpno) {
			var newrow = new Element('tr', {'class':'lggroup'});
			row.insert({before:newrow});
			var cell1 = newrow.insertCell(-1);
			var cell2 = newrow.insertCell(-1);
			var cell3 = newrow.insertCell(-1);
			cell1.colSpan = 3;
			cell2.colSpan = 2;
			cell3.colSpan = visiblecols - 5;
			cell1.innerHTML = grpno + ' ' + grp;
			cell2.className = "noedit"; // prevent tablekit from trying to edit this cell. Not needed for cell1 since it's in the rn column
			cell3.className = "noedit";
			if (stedtuserprivs & 1) {
				// insert html form for approving this subgroup only
				grp = grp.replace(/"/g,'&quot;'); // escape quotes for inclusion in the string below
				cell2.innerHTML = '<form action="' + baseRef + 'tags/accept" method="post" '
					+ 'onsubmit="return grp_confirm(' + table_tag + ',\'' + grp + '\')">'
					+ '<input name="tag" value="' + table_tag + '" type="hidden">'
					+ '<input name="uid" value="' + uid2 + '" type="hidden">'
					+ '<input name="grpno" value="' + grpno + '" type="hidden">'
					+ '<input type="submit" value="Accept ' + grp + ' only"></form>';
				// insert html form for migrating tagged reflexes in this subgroup
				cell3.innerHTML = '<button onclick="migrate_prompt(' + table_tag + ',\'' + grp
					+ '\'' + ',\'' + grpno + '\')">Move tagged reflexes to another tag</button>';
			}
			lastgrpno = grpno;
		}
	});
}
