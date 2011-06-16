var baseRef = location.pathname.substring(0,location.pathname.lastIndexOf(".pl") + 3) + '/';

function findPos(obj) { // based on http://www.quirksmode.org/js/findpos.html
	var curleft = curtop = 0;
	if (obj.offsetParent) { // if the browser supports offsetParent
		do {
			if (obj === $('lexicon')) break;
			curleft += obj.offsetLeft;
			curtop += obj.offsetTop;
		} while (obj = obj.offsetParent);
		return [curleft,curtop];
	}
};

// code to make things draggable and droppable for the subroots
makesubroot = function(dragged, destination, e) {
	var data = TableKit.tables['etyma_resulttable'].raw.data;
	var cols = TableKit.tables['etyma_resulttable'].raw.cols;
	src = dragged.identify().sub('tag',''); // get just the numbers (id is "tag###")
	dst = destination.identify().sub('tag','');
	var srcsuper = data[src][cols['etyma.supertag']];
	new Ajax.Request(baseRef + 'makesubroot/' + src + '/' + dst + '/' + srcsuper, {
		onSuccess: function(transport) {
			if (srcsuper == dst) {
				// if it's already the subroot of the destination, 
				// make it a main root, and resort.
				data[src][cols['etyma.supertag']] = src;
				destination.up('tbody').insert(dragged.up('tr'));
				dragged.up('td').nextSibling.innerHTML = '';
			} else {
				data[src][cols['etyma.supertag']] = dst;
				destination.up('tr').insert({after:dragged.up('tr')});
				dragged.up('td').nextSibling.innerHTML = dst;
			}
			
			// restripe
			TableKit.reload();
		},
		onFailure: function(transport) {
			alert(transport.responseText);
		}
	});
};
var make_draggable_id = function (obj, scrollElement) { // scrollElement is the containing element which should be scrolled, if any
	new Draggable(obj, { revert:true, constraint:'vertical', scroll:scrollElement });
	Droppables.add(obj,
	  { hoverclass : 'hoverdrop',
		accept : 'tagid',
		onDrop : makesubroot
	  } );
};

function show_notes(rn) {
	new Ajax.Updater('notes' + rn, baseRef + 'notes/l/' + rn, {
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
	return false;
};


var current_cog = 0;
function show_cognates(tag) {
	if (current_cog) {
		$$('.r' + current_cog).each(function (item) {item.removeClassName('cognate')});
	}
	$$('.r' + tag).each(function (item) {item.addClassName('cognate')});
	current_cog = tag;
};

var make_one_table = function (tablename, tabledata) {
	// make a table
	var t = $(tablename + '_resulttable');
	if (t) {
		t.remove();
		TableKit.unloadTable(t);
	}
	t = $(document.createElement('table')); // $() extends it into a Prototype Element
	t.id = tablename + '_resulttable';
	t.width = '100%';
	t.style.tableLayout = 'fixed';
	$(tablename + '_results').appendChild(t);

	// make the header
	// this is where we make columns editable (by setting the id) or not
	var thead = t.createTHead();
	var row = thead.insertRow(-1); // -1 is the index value for "at the end", and is required for firefox
	var rawDataCols = {}; // lookup table for column id -> index
	tabledata.fields.each(function (fld, i) {
		if (!setup[tablename][fld]) {
			setup[tablename][fld] = { noedit:true };
		}
		if (!setup[tablename][fld].hide) {
			var c = $(document.createElement('th'));
			if (setup[tablename][fld].noedit)
				c.addClassName('noedit');
			else
				c.id = fld;
			if (setup[tablename][fld].nosort)
				c.addClassName('nosort');
			if (setup[tablename][fld].size)
				c.width = setup[tablename][fld].size;
			c.innerHTML = setup[tablename][fld].label || fld;
			row.appendChild(c);
		}
		rawDataCols[fld] = i;
	});
	
	// find index of key field
	var k;
	for (k = 0; k < tabledata.fields.length; ++k) {
		if (tabledata.fields[k] == setup[tablename]._key)
			break;
	}

	// stick in the data
	var tbody = $(document.createElement('tbody'));
	var rawData = {};
	t.appendChild(tbody);
	tabledata.data.each(function (rec) {
		var row = tbody.insertRow(-1);
		row.id = rec[k];	// set this for TableKit.Editable
		rawData[row.id] = rec;
		rec.each(function (v,i) {
			var xform = setup[tablename][tabledata.fields[i]].transform;
			var cell;
			// add the cell if column is visible
			if (!setup[tablename][tabledata.fields[i]].hide) {
				cell = row.insertCell(-1);
				cell.innerHTML = xform	? xform(v ? v.escapeHTML() : '', rec[k], rec, i)
										: v ? v.escapeHTML() : '';
			}
		});
	});
	
	// activate TableKit!
	// t.addClassName('sortable'); // not needed if manually initing
	TableKit.Sortable.init(t);
	TableKit.Resizable.init(t);
	TableKit.options.defaultSort = 1;
	TableKit.tables[t.id].raw = {};
	TableKit.tables[t.id].raw.data = rawData;
	TableKit.tables[t.id].raw.cols = rawDataCols;
	if (stedtuserprivs >= 16) {
		TableKit.Editable.init(t);
		TableKit.tables[t.id].editAjaxURI = baseRef + 'update';
		TableKit.tables[t.id].editAjaxExtraParams = '&tbl=' + tablename;
		TableKit.tables[t.id].editAjaxTransform = function (tbl, fld, key, val, rec) {
			var xform = setup[tbl][fld].transform;
			return xform ? xform(val, key, rec) : val;
		};
	}
	if (setup[tablename]._postprocess) {
		var fn = setup[tablename]._postprocess;
		fn();
	}
};
var ajax_make_table = function (transport,json){ // function suitable for the onSuccess callback
	var response = transport.responseText || "ERROR: no response text";
	response = response.evalJSON();
	var tablename = response.table;
	if (tablename === 'simple') {
		$('splash').hide();
		$('header').show();
		$('etyma').show();
		$('dragger').show();
		$('lexicon').show();
		make_one_table('etyma', response.etyma);
		make_one_table('lexicon', response.lexicon);
	} else {
		make_one_table(tablename, response);
	}
};
function show_supporting_forms(tag) {
	new Ajax.Request(baseRef + 'search/lexicon', {
		parameters: { 'analysis' : tag },
		onSuccess: function (transport,json) { ajax_make_table(transport,json); show_cognates(tag); },
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
	return false;
};

function SylStation() {
	var tonechars = "⁰¹²³⁴⁵⁶⁷⁸0-9ˊˋ";
	var delimchars = "-=≡≣+.,;/~◦⪤ ";
	var rebytonepostfix = "([^" + delimchars + tonechars + "]+[" + tonechars + "]+)([" + delimchars + "]*)";
	var rebytoneprefix = "([" + tonechars + "]{1,2}[^" + delimchars + tonechars + "]+)([" + delimchars + "]*)";
	var rebydelims = "([^" + delimchars + "]+)([" + delimchars + "]*)";

	var syl_ary;   // array of parsed out "syllables"
	var delim_ary; // array of the delimiters following the "syllables", above

	var syllabify_by_regex = function (s, re) {
		var is_suffix = /^-/.test(s);
		if (is_suffix) s = s.replace(/^-/,'');
	
		var re1 = new RegExp("^" + re); // regexp for parsing out syllables in our while loop
		var tmp_syl, tmp_delim; // vars for holding results from the regex test

		syl_ary = []; // clear out our arrays
		delim_ary = [];

		while (re1.test(s)) {
			s = s.replace(re1, '');
			tmp_syl = RegExp.$1;
			tmp_delim = RegExp.$2;
			if (/\|/.test(tmp_syl) && syl_ary.length) {
				tmp_syl = tmp_syl.replace(/\|/, '');          // overriding delim
				syl_ary[syl_ary.length-1] += delim_ary.pop();
				syl_ary[syl_ary.length-1] += tmp_syl;
			} else {
				syl_ary.push(tmp_syl);
			}
			delim_ary.push(tmp_delim.replace(/◦/,'&thinsp;')); // STEDT delim -> thin space
		}
		syl_ary[0] = syl_ary[0] || '';
		if (is_suffix) {
			syl_ary[0] = "-" + syl_ary[0];
		}
		if (s) { // if it fails, we should append the residue at the end
			syl_ary[syl_ary.length-1] += s;
		}
		return !s.length; // true if the parsing was exhaustive, false if there's leftover unmatchable cruft
	};
	this.syllabify = function (s, n) { // string and number of tags to match
		if (!syllabify_by_regex(s, rebytonepostfix)) {
			if (!syllabify_by_regex(s, rebytoneprefix)) {
				if (!syllabify_by_regex(s, rebydelims)) {
					// alert("no re matches! " + s + "\n" + syl_ary);
				}
			}
		}
		return [syl_ary, delim_ary];
	};
};
var SYLSTATION = new SylStation(); // for efficiency, we make this object once

var stedtadmin = stedtuserprivs >= 16;
var skipped_roots = {};
var public_roots = {};
[1,2,34,35,90,95,20,98,70,97,71,92,66,67,109,119,103,111,138,132,142,
127,130,145,131,126,178,157,181,160,1018,19,692,387,385,386,367,251,
243,359,682,33,685,814,821,824,820,822,803,804,805,471,468,478,686,441
,454,76,625,628,621,629,630,36,481,480,563,292,253,254,259,164,137,203
,206,201,403,409,696,418,306,432,769,511,512,335,346,776,774,380,363,
230,232,459,42,48,60,40,790,783,589,590,780,586,591,448,782,792,588,
595,593,585,795,592,785,596,781,784,562,530,533,1381,1390,457,229,600,
601,604,603,540,650,572,1292,1160,1154,1288,641,1286,548,545,1284,1283
,547,796,642,646,643,661,668,1353,667,1354,662,665,664,1356,1352,1349,
1359,298,304,305,301,1181,1172,1168,1234,1233,670,1347,679,672,677,675
,673,520,526,519,528,527,529,517,525,659,1011,188,1013,191,1019,1110,
1016,1006,1012,1007,156,1017,85,180,1281,1289,1310,1306,1317,258,276,
1276,1277,1278,1279,1226,1227,1229,1230,1235,1269,1275,1601,1408,1415,
1417,1603,1604,1605,1606,1607,1609,1610,1611,1612,1613,1615,1614,1616,
1617,1619,1620,1622,1623,1624,1626,1627,1628,1629,1631,1632,1633,1636,
1637,1638,1639,1640,1431,1643,1647,1645,1646,1454,1456,1457,1458,1459,
1460,1462,1455,487,502,503,504,627,688,743,1103,1104,1105,1108,1706,
1722,1733,1796,1752,1753,1754,1758,1764,1786,1787,1788,1794,1651,1654,
1473,1811,1812,1813,1844,1845,1860,1863,1864,1865,2108,2110,2111,1906,
2071,2080,2081,2135,2136,2137,2142,2143,2144,2146,2149,2152,2153,2154,
2155,2156,2157,2158,2159,2160,2165,2166,2167,2170,2171,2177,2178,2180,
2182,2187,2188,2190,3563,2193,2195,300,2197,2198,2200,2202,2204,2206,
2207,2215,2218,1779,2221,2222,2224,2228,2232,2233,2234,2235,2238,2239,
2241,2243,1867,2245,2247,2249,2250,2251,2252,2254,2256,2258,2259,2260,
2264,2268,2270,2271,2274,2275,2280,3383,2284,2296,2297,2300,2301,2302,
2304,2306,2308,2310,2312,2313,2314,2315,2316,2317,2321,2322,2325,2328,
2331,2332,2333,2334,2336,2337,2339,2340,2341,2344,2346,2347,2348,2349,
2353,2355,2357,2358,2359,2360,2361,2362,2364,2365,2367,2369,2370,2374,
2375,2377,2378,2379,2381,2386,2389,2393,2395,2397,2400,2401,2406,2407,
2408,2409,2410,2411,2412,2413,2414,2415,2416,2418,2420,2425,2426,2427,
2428,2432,2433,2439,2440,2443,2444,2447,2449,2450,2453,2455,2457,2458,
2459,2460,2463,2464,2465,2467,2468,2471,2472,2473,2475,2477,2478,2483,
2484,2486,2487,2488,2489,2491,2492,2493,46,2496,2498,2499,2501,2504,
2505,2507,2508,2510,2512,2514,2517,182,2520,2523,2526,2528,2530,2531,
2533,2534,2535,2538,2541,2543,2546,2549,2550,2553,2555,2557,2559,2560,
2562,2563,2567,2571,2572,2573,2576,2577,2579,2580,2582,2583,2585,2587,
2588,2589,2590,2592,2594,2595,2597,2599,2602,2603,2606,2607,2608,2609,
2610,2611,2615,2616,2617,2618,2620,2621,2623,2624,2625,2627,2628,2630,
2631,2633,2634,2640,2643,2644,2645,2652,2653,2658,2662,2666,1797,2670,
2672,2673,2674,2676,2680,2682,2686,2688,118,2690,2691,2692,2693,2694,
2697,2702,2703,2704,183,2707,2708,2709,2712,2718,2719,2721,2724,2727,
2729,2731,2732,2737,2738,2739,2741,2742,2743,2744,2746,2748,2749,2750,
2751,2752,2753,2757,2760,2763,2764,2765,2767,2768,2772,2773,2774,2060,
2777,2780,2781,2782,2784,2786,2789,2790,2794,2795,2796,2797,2798,2804,
2805,2806,3372,3374,3420,3421,3423,3425,3426,3428,3429,3430,3431,3432,
3434,3436,3437,3438,3439,3444,3445,3446,3447,3450,3451,3452,3453,3455,
3456,3457,3458,3459,3461,3462,3463,3464,3465,3466,3467,3469,3470,3471,
3472,3473,3474,3475,3476,3477,3478,3480,3481,3482,3483,3484,3485,3486,
3487,3488,3489,3490,3491,3492,3493,3494,3497,3557,3558,3559,3572,680,
674,1285,518,3584,3585,3586,3587,3588,3589,3590,599,598,4353,4698,5048,3000].each( function (n) {public_roots[n] = true;});
function show_root(tag) {
	new Ajax.Request(baseRef + 'search/etyma', {
		parameters: { 'etyma.tag' : tag },
		onSuccess: function (transport,json) { ajax_make_table(transport,json); show_cognates(tag); },
		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
	});
};
function show_tag(tag,loc) {
// 	new Ajax.Request(baseRef + 'search/etyma', {
// 		parameters: { 'etyma.tag' : tag },
// 		onSuccess: ajax_make_table,
// 		onFailure: function (transport){ alert('Error: ' + transport.responseText); }
// 	});
	var x = $('info');
// 	if (x.visible()) {
// 		x.hide();
// 	} else {
		x.innerHTML = tag;
		x.setStyle({left:loc[0] + 'px', top:loc[1] + 'px'});
		x.show();
// 	}
};

// maybe better to return a fn, not a string, for transforms
var setup = { // in the form setup.[tablename].[fieldname]
	etyma : {
		_key: 'etyma.tag',   // maybe send it from the server?
		_postprocess: function () {
			var scrollElem = $('etyma') || window; // if we're not in the combo view, there's no etyma div; if we pass a nonexistent element to Draggable, prototype will crash (in firefox and possibly other browsers)
			$$('.tagid').each(function(obj, index) {
				make_draggable_id(obj, scrollElem);
			});
			// put in a special sort function for all columns of the table
			var t = TableKit.tables['etyma_resulttable'];
			t.customSortFn = function (rows, index, tkstdt) {
				var sindex = t.raw.cols['etyma.supertag'];
				var pindex = t.raw.cols['etyma.plgord'];
				rows.sort(function (a,b) {
					var asid = t.raw.data[a.id][sindex];
					var bsid = t.raw.data[b.id][sindex];
					var super_a_val = t.raw.data[asid][index];
					var super_b_val = t.raw.data[bsid][index];
					// sort by superroot's values
					var result = tkstdt.compare(super_a_val, super_b_val);
					if (result === 0) {
						// fall back to the supertag
						result = t.raw.data[a.id][sindex] - t.raw.data[b.id][sindex];
						if (result === 0) {
							// fall back to plgord
							result = t.raw.data[a.id][pindex] - t.raw.data[b.id][pindex];
						}
					}
					return result;
				});
			};
		},
		'etyma.tag' : {
			label: 'TAG',
			noedit: true,
			hide: stedtuserprivs < 16,
			size: 40,
			transform: function (v) {
				return '<span id="tag' + v
					+ '" class="tagid">' + v + '</span>';
			}
		},
		'etyma.supertag' : {
			label: 'super',
			nosort: true,
			hide: stedtuserprivs < 16,
			size: 40,
			transform: function (v,key) {
				 return v === key ? '' : v;
			}
		},
		'num_recs' : {
			label: 'reflexes',
			noedit: true,
			size: 50,
			transform: function (v,key) {
				 return v != 0
				 	? '<a href="#" onclick="show_supporting_forms(' + key + ')">' + v + '&nbsp;r\'s</a>'
				 	: v + '&nbsp;r\'s';
			}
		},
		'etyma.chapter' : {
			label: 'ch.',
			size: 70
		},
		'etyma.protoform' : {
			label: 'protoform',
			size: 120
		},
		'etyma.protogloss' : {
			label: 'protogloss',
			size: 200
		},
		'etyma.plg' : {
			label: 'plg',
			size: 40
		},
		'etyma.plgord' : {
			label: 'plgord',
			hide: true,
			size: 40
		},
		'etyma.notes' : {
			label: 'tagging note',
			size: 160
		},
		'etyma.hptbid' : {
			label: 'HPTB',
			size: 70,
			transform: function (v) {
				if (v === '') return '';
				v = v.replace(/, */g,', ');
				return '<a href="hptb.pl?submit=Search&hptbid=' + v
					+ '" target="hptbwindow">' + v + '</a>';
			}
		},
		'num_notes' : {
			label: 'notes',
			noedit: true,
			size: 150,
			transform: function (v,key) {
				return '<a href="' + baseRef + 'etymon/' + key + '" target="stedt_etymon">'
					+ v + '&nbsp;note' + (v == 1 ? '' : 's')
					+ '</a>';
			}
//also make sure non-logged in users can't add notes (take care of "0" case)

		},
		'etyma.xrefs' : {
			label: 'xrefs',
			size: 20
		},
		'etyma.exemplary' : {
			label: 'x',
			size: 10
		},
		'etyma.sequence'  : {
			label: 'seq',
			noedit: true,
			size: 55
		},
		'etyma.printseq'  : {
			label: '(#)',
			size: 50,
			transform: function (v) {
				if (v === '') return '';
				return '(' + v + ')';
			}
		},
		'etyma.possallo'  : {
			label: '⪤?',
			size: 40
		},
		'etyma.allofams' : {
			label: '⪤',
			size: 20
		},
		'etyma.public' : {
			label: 'public',
			size: 15
		}
	},
	lexicon : {
		_key: 'lexicon.rn',
		'lexicon.rn' : {
			label: 'rn',
			noedit: true,
			hide: stedtuserprivs < 16,
			size: 70
		},
		'analysis' : {
			label: 'analysis',
			hide: stedtuserprivs < 16,
			size: 80,
			transform: function (v) {
				return v.replace(/, */g,', ');
			}
		},
		'user_an' : {
			label: 'my analysis',
			hide: stedtuserprivs < 16,
			size: 80,
			transform: function (v) {
				return v.replace(/, */g,', ');
			},
		},
		'languagenames.lgid' : {
			label:'lgid',
			noedit: true,
			hide: true
		},
		'lexicon.reflex' : {
			label: 'form',
			size: 160,
			transform: function (v,key,rec) {
				if (!v) return '';
				var analysis = rec[1] || ''; // might be NULL from the SQL query
				var tags = analysis.split(',');
				var result = SYLSTATION.syllabify(v);
				var a = result[0].map(function (s,i) {
					var delim = result[1][i] || '&thinsp;';
					var makelink = !skipped_roots[tags[i]] && (stedtadmin || public_roots[tags[i]]);
					return (parseInt(tags[i], 10) && makelink)
						? '<a href="' + baseRef + 'etymon/' + tags[i] + '" target="stedt_etymon"'
							+ ' class="r' + tags[i] + '">'
							+ s + '</a>'  + delim
// 						? '<a href="' + baseRef + 'etyma/' + tags[i]
// 							+ '" onclick="'
// //							+ 'alert(event.element().cumulativeScrollOffset());'
// 							+ 'show_root(' + tags[i]  // + ', findPos(event.element())
// 							+ '); return false;"'
// 							+ '" class="r' + tags[i] + '">'
// 							+ s + '</a>' + delim
						: '<span class="r' + tags[i] + '">' + s + '</span>' + delim;
				});
				return a.join('');
			}
		},
		'lexicon.gloss' : {
			label: 'gloss',
			size: 160
		},
		'lexicon.gfn' : {
			label: 'gfn',
			size: 30
		},
		'languagenames.language' : {
			label: 'language',
			noedit: true,
			size: 100,
			transform : function (v, key, rec, n) {
				return '<a href="' + baseRef + 'group/' + rec[n+1] + '/' + rec[2] + '" target="stedt_grps">' + v + '</a>';
			}
		},
		'languagegroups.grpid' : {
			label: 'grpid',
			noedit: true,
			hide: true
		},
		'languagegroups.grpno' : {
			label: 'group',
			noedit: true,
			size: 120,
			transform : function (v, key, rec, n) {
				return v + ' - ' + rec[n+1];
			}
		},
		'languagegroups.grp' : {
			label: 'grp',
			noedit: true,
			hide: true
		},
		'languagenames.srcabbr' : {
			label: 'srcabbr',
			noedit: true,
			size: 80,
			hide: true
		},
		'lexicon.srcid' : {
			label: 'source',
			size: 140,
			transform : function (v, key, rec, n) {
				return '<a href="' + baseRef + 'source/' + rec[n-1] + '" target="stedt_src">' + rec[n-1] + '</a>'
					+ (v ? ':&thinsp;' + v : '');
			}
		},
		'lexicon.semcat' : {
			label: 'semcat'
		},
		'num_notes' : {
			label: 'notes',
			noedit: true,
			size: 200,
			transform: function (v,key) {
				if (v == 0) return '';
				return '<span id="notes' + key +  '"><a href="#" '
					+ 'onclick="show_notes(' + key + ')">'
					+ v + '&nbsp;note' + (v == 1 ? '' : 's')
					+ '</a></span>';
			}
		},
		'languagegroups.ord' : {
			noedit: true,
			size: 40,
			hide: true
		}
	}
};
