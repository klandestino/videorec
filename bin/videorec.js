var videorec = {
	pattern: '*[data_videorec]',
	swf: 'videorec.swf',
	width: 600,
	height: 400,

	init: function () {
		if (typeof (window ['swfobject']) != 'undefined' && typeof (window ['jQuery']) != 'undefined') {
			$(document).ready (videorec.hook);
		}
	},

	hook: function () {
		$(videorec.pattern).ready (videorec.generate);
	},

	generate: function () {
		var jElm = $(videorec.pattern);

		var id = new String (jElm.attr ('id'));
		if (id.length <= 0 || id == 'undefined') {
			var count = 0;
			id = 'videorec' + count;
			while (document.getElementById (id)) {
				count++;
				id = 'videorec' + count;
			}
		}

		jElm.width (videorec.width);
		jElm.height (videorec.height);

		var params = {
			sessionid: jElm.attr ('sessionid'),
			connectionurl: jElm.attr ('data_connection_url'),
			recordtime: jElm.attr ('recordtime'),
			recordsrc: jElm.attr ('data_record_src'),
			recordx: jElm.attr ('data_record_x'),
			recordy: jElm.attr ('data_record_y'),
			uploadsrc: jElm.attr ('data_upload_src'),
			uploadx: jElm.attr ('data_upload_x'),
			uploady: jElm.attr ('data_upload_y'),
			playsrc: jElm.attr ('data_play_src'),
			playx: jElm.attr ('data_play_x'),
			playy: jElm.attr ('data_play_y'),
			info1src: jElm.attr ('data_info1_src'),
			info1x: jElm.attr ('data_info1_x'),
			info1y: jElm.attr ('data_info1_y'),
			info2src: jElm.attr ('data_info2_src'),
			info2x: jElm.attr ('data_info2_x'),
			info2y: jElm.attr ('data_info2_y'),
			info3src: jElm.attr ('data_info3_src'),
			info3x: jElm.attr ('data_info3_x'),
			info3y: jElm.attr ('data_info3_y')
		};

		jElm.replaceWith ('<div id="' + id + '"></div>');
		swfobject.embedSWF (videorec.swf, id, videorec.width, videorec.height, '10.0.0', null, params);
	}
}

videorec.init ();