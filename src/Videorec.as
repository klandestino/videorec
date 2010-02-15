package {

	import com.klandestino.debug.Debug;
	import com.klandestino.debug.loggers.NullLogger;
	import com.klandestino.debug.loggers.TraceLogger;
	import com.klandestino.utils.StringUtil;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.utils.Timer;

	/**
	 *	Sprite sub class description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 9.0
	 *
	 *	@author Olof Montin
	 *	@since  02.02.2010
	 */
	public class Videorec extends Sprite {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const MSG_NO_CAMERA:String = 'No camera connected or available!';
		public static const MSG_NO_CONNECTION:String = 'Server connection failed!';
		public static const MSG_SECURITY_ERROR:String = 'Server connection failed with a security error!';

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function Videorec () {
			super ();

			Debug.addLogger (new TraceLogger ());
			//Debug.addLogger (new NullLogger ());

			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.addEventListener (Event.RESIZE, this.init, false, 0, true);
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}
		
		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		[Embed(source="../assets/loader.swf")]
		private var loaderMovieClass:Class;

		private var blur:Number = 20;
		private var buttonPlay:Object;
		private var buttonRecord:Object;
		private var buttonUpload:Object;
		private var camera:Camera;
		private var connection:NetConnection;
		private var connectionURL:String = 'rtmp://gts.dartmotif.com/camera_recorder/testpotter';
		private var currentInfoScreen:Object;
		private var currentInfoScreenNum:int = 0;
		private var infoScreen1:Object;
		private var infoScreen2:Object;
		private var infoScreen3:Object;
		private var loaderMovie:Sprite;
		private var recordTime:int = 10;
		private var recordTimeLeft:int = 0;
		private var recordTimer:Timer;
		private var sessionID:String = String (Math.random ()).split ('.')[1];
		private var statusText:TextField;
		private var stream:NetStream;
		private var timerStatusText:TextField;
		private var video:Video;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function play ():void {
			Debug.debug ('Playing recorded stream');
			this.removeLoaderMovie ();
			this.removeInfoScreen ();
			this.video.attachNetStream (this.stream);
			this.stream.play (this.connectionURL + '/' + this.sessionID + '.flv');
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		public function reset ():void {
			Debug.debug ('Resetting');
			this.removeLoaderMovie ();
			this.removeTimer ();
			this.removeStatusMessage ();
			this.setupCamera ();
			this.setFilters ();
			this.setupInfoScreen (1);
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		public function record ():void {
			Debug.debug ('Start recording');
			this.removeLoaderMovie ();
			this.video.filters = null;
			this.removeInfoScreen ();
			this.camera.setLoopback (true);
			//this.stream.attachCamera (this.camera);
			//this.stream.publish (this.sessionID, 'record');
			this.setupTimer ();
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		public function stop ():void {
			Debug.debug ('Stopped recording');
			this.removeLoaderMovie ();
			//this.stream.close ();
			this.setFilters ();
			this.camera.setLoopback (false);
			this.setupInfoScreen (2);
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		public function upload ():void {
			Debug.debug ('Uploading recorded material');
			this.removeLoaderMovie ();
			this.setupInfoScreen (3);
			this.stage.dispatchEvent (new Event (Event.RESIZE));
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function stageResizeHandler (event:Event):void {
			Debug.debug ('Stage resize handling');
			this.setupVideoSize ();
			this.setupLoaderMoviePositions ();
			this.setupStatusMessagePositions ();
			this.setupTimerPositions ();
			this.setupInfoScreensPositions ();
			this.setupButtonsPositions ();
		}

		private function loaderCompleteHandler (event:Event):void {
			this.removeLoaderListeners (IEventDispatcher (event.target));
			var type:String = '';

			try {
				if (this.buttonPlay.loader.contentLoaderInfo === event.target) {
					type = 'play';
				}
			} catch (error:Error) {
				//
			}

			try {
				if (this.buttonRecord.loader.contentLoaderInfo === event.target) {
					type = 'record';
				}
			} catch (error:Error) {
				//
			}

			try {
				if (this.buttonUpload.loader.contentLoaderInfo === event.target) {
					type = 'upload';
				}
			} catch (error:Error) {
				//
			}

			try {
				if (this.infoScreen1.loader.contentLoaderInfo === event.target) {
					type = 'info1';
				}
			} catch (error:Error) {
				//
			}

			try {
				if (this.infoScreen2.loader.contentLoaderInfo === event.target) {
					type = 'info2';
				}
			} catch (error:Error) {
				//
			}

			try {
				if (this.infoScreen3.loader.contentLoaderInfo === event.target) {
					type = 'info3';
				}
			} catch (error:Error) {
				//
			}

			switch (type) {
				case 'play':
					Debug.debug ('Play button loaded');
					this.buttonPlay.sprite = new Sprite ();
					this.buttonPlay.sprite.visible = false;
					this.buttonPlay.sprite.addChild (this.buttonPlay.loader.contentLoaderInfo.content);
					this.buttonPlay.loader = null;
					this.addChild (this.buttonPlay.sprite);
					break;
				case 'record':
					Debug.debug ('Record button loaded');
					this.buttonRecord.sprite = new Sprite ();
					this.buttonRecord.sprite.visible = false;
					this.buttonRecord.sprite.addChild (this.buttonRecord.loader.contentLoaderInfo.content);
					this.buttonRecord.loader = null;
					this.addChild (this.buttonRecord.sprite);
					break;
				case 'upload':
					Debug.debug ('Upload button loaded');
					this.buttonUpload.sprite = new Sprite ();
					this.buttonUpload.sprite.visible = false;
					this.buttonUpload.sprite.addChild (this.buttonUpload.loader.contentLoaderInfo.content);
					this.buttonUpload.loader = null;
					this.addChild (this.buttonUpload.sprite);
					break;
				case 'info1':
					Debug.debug ('Info screen 1 loaded');
					this.infoScreen1.sprite = new Sprite ();
					this.infoScreen1.sprite.visible = false;
					this.infoScreen1.sprite.addChild (this.infoScreen1.loader.contentLoaderInfo.content);
					this.infoScreen1.loader = null;
					this.addChild (this.infoScreen1.sprite);
					break;
				case 'info2':
					Debug.debug ('Info screen 2 loaded');
					this.infoScreen2.sprite = new Sprite ();
					this.infoScreen2.sprite.visible = false;
					this.infoScreen2.sprite.addChild (this.infoScreen2.loader.contentLoaderInfo.content);
					this.infoScreen2.loader = null;
					this.addChild (this.infoScreen2.sprite);
					break;
				case 'info3':
					Debug.debug ('Info screen 3 loaded');
					this.infoScreen3.sprite = new Sprite ();
					this.infoScreen3.sprite.visible = false;
					this.infoScreen3.sprite.addChild (this.infoScreen3.loader.contentLoaderInfo.content);
					this.infoScreen3.loader = null;
					this.addChild (this.infoScreen3.sprite);
					break;
			}

			if (
				//this.stream != null &&
				this.buttonRecord.sprite != null &&
				(
					this.infoScreen1.sprite != null
					|| (
						//this.stream != null &&
						this.infoScreen1.loader == null &&
						this.infoScreen1.sprite == null
					)
				)
			) {
				this.reset ();
			}
		}

		private function loaderHttpStatusHandler (event:HTTPStatusEvent):void {
			if (event.status >= 400) {
				Debug.warn ('Loading returned with status code ' + event.status);
				this.removeLoaderListeners (IEventDispatcher (event.target));
			}
		}

		private function loaderIoErrorHandler (event:IOErrorEvent):void {
			Debug.error ('Loading returned with input/output error');
			this.removeLoaderListeners (IEventDispatcher (event.target));
		}

		private function buttonPlayClickHandler (event:MouseEvent):void {
			Debug.debug ('Play button clicked');
			this.play ();
		}

		private function buttonRecordClickHandler (event:MouseEvent):void {
			Debug.debug ('Record button clicked');
			this.record ();
		}

		private function buttonUploadClickHandler (event:MouseEvent):void {
			Debug.debug ('Upload button clicked');
			this.upload ();
		}

		private function recordTimerUpdateHandler (event:TimerEvent):void {
			this.recordTimeLeft--;
			var time:int = this.recordTimeLeft;
			var min:int = Math.floor (time / 60);
			var sec:int = time - (min * 60);
			this.timerStatusText.text = (min < 10 ? '0' : '') + min + ':' + (sec < 10 ? '0' : '') + sec;
			this.setupTimerPositions ();
		}

		private function recordTimerCompleteHandler (event:TimerEvent):void {
			Debug.debug ('Recording timer completed');
			this.removeTimer ();
			this.stop ();
		}

		private function connectionNetStatusHandler (event:NetStatusEvent): void {
			switch (event.info.code) {
				case 'NetConnection.Connect.Success':
					Debug.debug ('Succeded with net connection');
					this.setupNetStream ();
					break;
				case 'NetConnection.Connect.Failed':
					Debug.fatal ('Net connection failed');
					this.sendStatusMessage (Videorec.MSG_NO_CONNECTION);
					break;
			}
		}

		private function connectionSecurityErrorHandler (event:SecurityErrorEvent): void {
			this.sendStatusMessage (Videorec.MSG_SECURITY_ERROR);
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function init (event:Event):void {
			Debug.debug ('Initializing');
			this.stage.removeEventListener (Event.RESIZE, this.init);
			this.stage.addEventListener (Event.RESIZE, this.stageResizeHandler, false, 0, true);

			this.buttonPlay = new Object ();
			this.buttonRecord = new Object ();
			this.buttonUpload = new Object ();
			this.infoScreen1 = new Object ();
			this.infoScreen2 = new Object ();
			this.infoScreen3 = new Object ();

			this.getParams ();
			this.setupCamera ();
			this.setupLoaderMovie ();
			this.setupImages ();
			//this.setupNetConnection ();
			this.setupTimer ();
		}

		/**
		*	Gets the inserted parameters from the embedded player.
		*	<h4>Parameters:</h4>
		*	<ul>
		*		<li>sessionid – session identification</li>
		*		<li>connectionurl – URL to rtmp-server</li>
		*		<li>recordtime – time used to record defined in seconds</li>
		*		<li>recordsrc – record button source</li>
		*		<li>recordx – record button x coordinates</li>
		*		<li>recordy – record button y coordinates</li>
		*		<li>playsrc – play button source</li>
		*		<li>playx – play button x coordinates</li>
		*		<li>playy – play button y coordinates</li>
		*		<li>uploadsrc – upload button source</li>
		*		<li>uploadx – upload button x coordinates</li>
		*		<li>uploady – upload button y coordinates</li>
		*		<li>info1src – info 1 screen source</li>
		*		<li>info1x – info 1 x coordinates</li>
		*		<li>info1y – info 1 y coordinates</li>
		*		<li>info2src – info 2 screen source</li>
		*		<li>info2x – info 2 x coordinates</li>
		*		<li>info2y – info 2 y coordinates</li>
		*		<li>info3src – info 3 screen source</li>
		*		<li>info3x – info 3 x coordinates</li>
		*		<li>info3y – info 3 y coordinates</li>
		*	</ul>
		*/
		private function getParams ():void {
			/**
				SESSION ID
			**/

			var sessionID:String;

			try {
				if (this.loaderInfo.parameters.sessionid != null) {
					sessionID = this.loaderInfo.parameters.sessionid;
				}
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (sessionID))) {
				this.sessionID = sessionID;
				Debug.debug ('Session id found ' + this.sessionID);
			} else {
				Debug.warn ('No session id found');
			}

			/**
				CONNECTION URL
			**/

			var connectionURL:String;

			try {
				if (this.loaderInfo.parameters.connectionurl != null) {
					connectionURL = this.loaderInfo.parameters.connectionurl;
				}
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (connectionURL))) {
				this.connectionURL = connectionURL;
				Debug.debug ('Connection URL found ' + this.connectionURL);
			} else {
				Debug.warn ('No connection URL found');
			}

			/**
				RECORD TIME
			**/

			var recordTime:String;

			try {
				if (this.loaderInfo.parameters.recordtime != null) {
					recordTime = this.loaderInfo.parameters.recordtime;
				}
			} catch (error:Error) {
				//
			}

			if (!(isNaN (parseInt (recordTime)))) {
				this.recordTime = parseInt (recordTime);
				Debug.debug ('Record time found ' + this.recordTime);
			} else if (!(StringUtil.isEmpty (recordTime))) {
				Debug.warn ('Record time was not an integer ' + recordTime);
			} else {
				Debug.warn ('No record time found');
			}

			/**
				PLAY BUTTON
			**/

			var buttonPlay:Object = new Object ();

			try {
				buttonPlay.src = this.loaderInfo.parameters.playsrc;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonPlay.src))) {
				this.buttonPlay.src = buttonPlay.src;
				Debug.debug ('Play button source found ' + this.buttonPlay.src);
			} else {
				Debug.warn ('No play button source found');
			}

			try {
				buttonPlay.x = this.loaderInfo.parameters.playx;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonPlay.x))) {
				this.buttonPlay.x = buttonPlay.x;
				Debug.debug ('Play button x found ' + this.buttonPlay.x);
			} else {
				Debug.debug ('No play button x found');
			}

			try {
				buttonPlay.y = this.loaderInfo.parameters.playy;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonPlay.y))) {
				this.buttonPlay.y = buttonPlay.y;
				Debug.debug ('Play button y found ' + this.buttonPlay.y);
			} else {
				Debug.debug ('No play button y found');
			}

			/**
				RECORD BUTTON
			**/

			var buttonRecord:Object = new Object ();

			try {
				buttonRecord.src = this.loaderInfo.parameters.recordsrc;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonRecord.src))) {
				this.buttonRecord.src = buttonRecord.src;
				Debug.debug ('Record button source found ' + this.buttonRecord.src);
			} else {
				Debug.warn ('No record button source found');
			}

			try {
				buttonRecord.x = this.loaderInfo.parameters.recordx;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonRecord.x))) {
				this.buttonRecord.x = buttonRecord.x;
				Debug.debug ('Record button x found ' + this.buttonRecord.x);
			} else {
				Debug.debug ('No record button x found');
			}

			try {
				buttonRecord.y = this.loaderInfo.parameters.recordy;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonRecord.y))) {
				this.buttonRecord.y = buttonRecord.y;
				Debug.debug ('Record button y found ' + this.buttonRecord.y);
			} else {
				Debug.debug ('No record button y found');
			}

			/**
				UPLOAD BUTTON
			**/

			var buttonUpload:Object = new Object ();

			try {
				buttonUpload.src = this.loaderInfo.parameters.uploadsrc;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonUpload.src))) {
				this.buttonUpload.src = buttonUpload.src;
				Debug.debug ('Upload button source found ' + this.buttonUpload.src);
			} else {
				Debug.warn ('No upload button source found');
			}

			try {
				buttonUpload.x = this.loaderInfo.parameters.uploadx;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonUpload.x))) {
				this.buttonUpload.x = buttonUpload.x;
				Debug.debug ('Upload button x found ' + this.buttonUpload.x);
			} else {
				Debug.debug ('No upload button x found');
			}

			try {
				buttonUpload.y = this.loaderInfo.parameters.uploady;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonUpload.y))) {
				this.buttonUpload.y = buttonUpload.y;
				Debug.debug ('Upload button y found ' + this.buttonUpload.y);
			} else {
				Debug.debug ('No upload button y found');
			}

			/**
				INFO SCREEN 1
			**/

			var infoScreen1:Object = new Object ();

			try {
				infoScreen1.src = this.loaderInfo.parameters.info1src;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen1.src))) {
				this.infoScreen1.src = infoScreen1.src;
				Debug.debug ('Info screen 1 source found ' + this.infoScreen1.src);
			} else {
				Debug.warn ('No info screen 1 source found');
			}

			try {
				infoScreen1.x = this.loaderInfo.parameters.info1x;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen1.x))) {
				this.infoScreen1.x = infoScreen1.x;
				Debug.debug ('Info screen 1 x found ' + this.infoScreen1.x);
			} else {
				Debug.debug ('No info screen 1 x found');
			}

			try {
				infoScreen1.y = this.loaderInfo.parameters.info1y;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen1.y))) {
				this.infoScreen1.y = infoScreen1.y;
				Debug.debug ('Info screen 1 y found ' + this.infoScreen1.y);
			} else {
				Debug.debug ('No info screen 1 y found');
			}

			/**
				INFO SCREEN 2
			**/

			var infoScreen2:Object = new Object ();

			try {
				infoScreen2.src = this.loaderInfo.parameters.info2src;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen2.src))) {
				this.infoScreen2.src = infoScreen2.src;
				Debug.debug ('Info screen 2 source found ' + this.infoScreen2.src);
			} else {
				Debug.warn ('No info screen 2 source found');
			}

			try {
				infoScreen2.x = this.loaderInfo.parameters.info2x;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen2.x))) {
				this.infoScreen2.x = infoScreen2.x;
				Debug.debug ('Info screen 2 x found ' + this.infoScreen2.x);
			} else {
				Debug.debug ('No info screen 2 x found');
			}

			try {
				infoScreen2.y = this.loaderInfo.parameters.info2y;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen2.y))) {
				this.infoScreen2.y = infoScreen2.y;
				Debug.debug ('Info screen 2 y found ' + this.infoScreen2.y);
			} else {
				Debug.debug ('No info screen 2 y found');
			}

			/**
				INFO SCREEN 3
			**/

			var infoScreen3:Object = new Object ();

			try {
				infoScreen3.src = this.loaderInfo.parameters.info3src;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen3.src))) {
				this.infoScreen3.src = infoScreen3.src;
				Debug.debug ('Info screen 3 source found ' + this.infoScreen3.src);
			} else {
				Debug.warn ('No info screen 3 source found');
			}

			try {
				infoScreen3.x = this.loaderInfo.parameters.info3x;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen3.x))) {
				this.infoScreen3.x = infoScreen3.x;
				Debug.debug ('Info screen 3 x found ' + this.infoScreen3.x);
			} else {
				Debug.debug ('No info screen 3 x found');
			}

			try {
				infoScreen3.y = this.loaderInfo.parameters.info3y;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (infoScreen3.y))) {
				this.infoScreen3.y = infoScreen3.y;
				Debug.debug ('Info screen 3 y found ' + this.infoScreen3.y);
			} else {
				Debug.debug ('No info screen 3 y found');
			}
		}

		private function setFilters ():void {
			var filters:Array = new Array ();
			filters.push (new BlurFilter (this.blur, this.blur, BitmapFilterQuality.HIGH));
			this.video.filters = filters;
		}

		private function setupImages ():void {
			if (this.buttonPlay.src != null && this.buttonPlay.src != 'null' && this.buttonPlay.src != '') {
				Debug.debug ('Loading play button');
				this.buttonPlay.loader = new Loader ();
				this.addLoaderListeners (this.buttonPlay.loader.contentLoaderInfo);
				this.buttonPlay.loader.load (new URLRequest (this.buttonPlay.src));
			} else {
				Debug.warn ('No play button to load');
			}

			if (this.buttonRecord.src != null && this.buttonRecord.src != 'null' && this.buttonRecord.src != '') {
				Debug.debug ('Loading record button');
				this.buttonRecord.loader = new Loader ();
				this.addLoaderListeners (this.buttonRecord.loader.contentLoaderInfo);
				this.buttonRecord.loader.load (new URLRequest (this.buttonRecord.src));
			} else {
				Debug.warn ('No record button to load');
			}

			if (this.buttonUpload.src != null && this.buttonUpload.src != 'null' && this.buttonUpload.src != '') {
				Debug.debug ('Loading upload button');
				this.buttonUpload.loader = new Loader ();
				this.addLoaderListeners (this.buttonUpload.loader.contentLoaderInfo);
				this.buttonUpload.loader.load (new URLRequest (this.buttonUpload.src));
			} else {
				Debug.warn ('No upload button to load');
			}

			if (this.infoScreen1.src != null && this.infoScreen1.src != 'null' && this.infoScreen1.src != '') {
				Debug.debug ('Loading info screen 1');
				this.infoScreen1.loader = new Loader ();
				this.addLoaderListeners (this.infoScreen1.loader.contentLoaderInfo);
				this.infoScreen1.loader.load (new URLRequest (this.infoScreen1.src));
			} else {
				Debug.warn ('No info screen 1 to load');
			}

			if (this.infoScreen2.src != null && this.infoScreen2.src != 'null' && this.infoScreen2.src != '') {
				Debug.debug ('Loading info screen 2');
				this.infoScreen2.loader = new Loader ();
				this.addLoaderListeners (this.infoScreen2.loader.contentLoaderInfo);
				this.infoScreen2.loader.load (new URLRequest (this.infoScreen2.src));
			} else {
				Debug.debug ('No info screen 2 to load');
			}

			if (this.infoScreen3.src != null && this.infoScreen3.src != 'null' && this.infoScreen3.src != '') {
				Debug.debug ('Loading info screen 3');
				this.infoScreen3.loader = new Loader ();
				this.addLoaderListeners (this.infoScreen3.loader.contentLoaderInfo);
				this.infoScreen3.loader.load (new URLRequest (this.infoScreen3.src));
			} else {
				Debug.debug ('No info screen 3 to load');
			}
		}

		private function setupButtonsPositions ():void {
			var totalWidth:Number = 0, width1:Number = 0, width2:Number = 0;

			if (this.buttonPlay.sprite != null && isNaN (parseInt (this.buttonPlay.x)) && this.currentInfoScreenNum > 1) {
				width2 = this.buttonPlay.sprite.width;
				totalWidth += width2;
			}

			if (this.buttonRecord.sprite != null && isNaN (parseInt (this.buttonRecord.x))) {
				totalWidth += this.buttonRecord.sprite.width;
			}

			if (this.buttonUpload.sprite != null && isNaN (parseInt (this.buttonUpload.x)) && this.currentInfoScreenNum > 1) {
				width1 = this.buttonUpload.sprite.width;
				totalWidth += width1;
			}

			Debug.debug ('Buttons total width ' + totalWidth);

			if (this.buttonPlay.sprite != null) {
				if (!isNaN (parseInt (this.buttonPlay.x))) {
					this.buttonPlay.sprite.x = parseInt (this.buttonPlay.x);
				} else if (!isNaN (parseInt (this.buttonPlay.y))) {
					this.buttonPlay.sprite.x = (this.stage.stageWidth - this.buttonPlay.sprite.width) / 2;
				} else {
					this.buttonPlay.sprite.x = ((this.stage.stageWidth - totalWidth) / 2) + width1;
				}

				if (!isNaN (parseInt (this.buttonPlay.y))) {
					this.buttonPlay.sprite.y = parseInt (this.buttonPlay.y);
				} else if (this.currentInfoScreen != null) {
					this.buttonPlay.sprite.y = this.currentInfoScreen.sprite.y + this.currentInfoScreen.sprite.height;
				} else {
					this.buttonPlay.sprite.y = (this.stage.stageHeight - this.buttonPlay.sprite.height) / 2;
				}
			}

			if (this.buttonRecord.sprite != null) {
				if (!isNaN (parseInt (this.buttonRecord.x))) {
					this.buttonRecord.sprite.x = parseInt (this.buttonRecord.x);
				} else if (!isNaN (parseInt (this.buttonRecord.y))) {
					this.buttonRecord.sprite.x = (this.stage.stageWidth - this.buttonRecord.sprite.width) / 2;
				} else {
					this.buttonRecord.sprite.x = ((this.stage.stageWidth - totalWidth) / 2) + width1 + width2;
				}

				if (!isNaN (parseInt (this.buttonRecord.y))) {
					this.buttonRecord.sprite.y = parseInt (this.buttonRecord.y);
				} else if (this.currentInfoScreen != null) {
					this.buttonRecord.sprite.y = this.currentInfoScreen.sprite.y + this.currentInfoScreen.sprite.height;
				} else {
					this.buttonRecord.sprite.y = (this.stage.stageHeight - this.buttonRecord.sprite.height) / 2;
				}
			}

			if (this.buttonUpload.sprite != null) {
				if (!isNaN (parseInt (this.buttonUpload.x))) {
					this.buttonUpload.sprite.x = parseInt (this.buttonUpload.x);
				} else if (!isNaN (parseInt (this.buttonUpload.y))) {
					this.buttonUpload.sprite.x = (this.stage.stageWidth - this.buttonUpload.sprite.width) / 2;
				} else {
					this.buttonUpload.sprite.x = (this.stage.stageWidth - totalWidth) / 2;
				}

				if (!isNaN (parseInt (this.buttonUpload.y))) {
					this.buttonUpload.sprite.y = parseInt (this.buttonUpload.y);
				} else if (this.currentInfoScreen != null) {
					this.buttonUpload.sprite.y = this.currentInfoScreen.sprite.y + this.currentInfoScreen.sprite.height;
				} else {
					this.buttonUpload.sprite.y = (this.stage.stageHeight - this.buttonUpload.sprite.height) / 2;
				}
			}
		}

		private function setupInfoScreensPositions ():void {
			for (var i:int = 1, l:int = 4; i < l; i++) {
				if (this ['infoScreen' + i].sprite != null) {
					if (!isNaN (parseInt (this ['infoScreen' + i].x))) {
						this ['infoScreen' + i].sprite.x = parseInt (this ['infoScreen' + i].x);
					} else {
						this ['infoScreen' + i].sprite.x = (this.stage.stageWidth - this ['infoScreen' + i].sprite.width) / 2;
					}

					if (!isNaN (parseInt (this ['infoScreen' + i].x))) {
						this ['infoScreen' + i].sprite.y = parseInt (this ['infoScreen' + i].y);
					} else {
						this ['infoScreen' + i].sprite.y = (this.stage.stageHeight - this ['infoScreen' + i].sprite.height) / 2;
					}
				}
			}
		}

		private function removeInfoScreen ():void {
			if (this.currentInfoScreen != null) {
				if (this.currentInfoScreen.sprite != null) {
					this.currentInfoScreen.sprite.visible = false;
				}
			}

			if (this.buttonPlay.sprite != null) {
				this.buttonPlay.sprite.visible = false;
				this.buttonPlay.sprite.buttonMode = false;
				this.buttonPlay.sprite.removeEventListener (MouseEvent.CLICK, this.buttonPlayClickHandler);
			}

			if (this.buttonRecord.sprite != null) {
				this.buttonRecord.sprite.visible = false;
				this.buttonRecord.sprite.buttonMode = false;
				this.buttonRecord.sprite.removeEventListener (MouseEvent.CLICK, this.buttonRecordClickHandler);
			}

			if (this.buttonUpload.sprite != null) {
				this.buttonUpload.sprite.visible = false;
				this.buttonUpload.sprite.buttonMode = false;
				this.buttonUpload.sprite.removeEventListener (MouseEvent.CLICK, this.buttonUploadClickHandler);
			}

			this.currentInfoScreen = null;
			this.currentInfoScreenNum = 0;
		}

		private function setupInfoScreen (num:int):void {
			Debug.debug ('Setting up info screen ' + num);

			this.currentInfoScreen = this ['infoScreen' + num];
			this.currentInfoScreenNum = num;

			this.setupInfoScreensPositions ();
			this.setupButtonsPositions ();

			if (this.buttonPlay.sprite != null) {
				this.buttonPlay.sprite.visible = (num == 2);
				this.buttonPlay.sprite.buttonMode = (num == 2);
				this.buttonPlay.sprite.mouseChildren = false;
				if (num == 2) {
					this.buttonPlay.sprite.addEventListener (MouseEvent.CLICK, this.buttonPlayClickHandler, false, 0, false);
				} else {
					this.buttonPlay.sprite.removeEventListener (MouseEvent.CLICK, this.buttonPlayClickHandler);
				}
			}

			if (this.buttonRecord.sprite != null) {
				this.buttonRecord.sprite.visible = (num < 3);
				this.buttonRecord.sprite.buttonMode = (num < 3);
				this.buttonRecord.sprite.mouseChildren = false;
				if (num < 3) {
					this.buttonRecord.sprite.addEventListener (MouseEvent.CLICK, this.buttonRecordClickHandler, false, 0, false);
				} else {
					this.buttonRecord.sprite.removeEventListener (MouseEvent.CLICK, this.buttonRecordClickHandler);
				}
			}

			if (this.buttonUpload.sprite != null) {
				this.buttonUpload.sprite.visible = (num == 2);
				this.buttonUpload.sprite.buttonMode = (num == 2);
				this.buttonUpload.sprite.mouseChildren = false;
				if (num == 2) {
					this.buttonUpload.sprite.addEventListener (MouseEvent.CLICK, this.buttonUploadClickHandler, false, 0, false);
				} else {
					this.buttonUpload.sprite.removeEventListener (MouseEvent.CLICK, this.buttonUploadClickHandler);
				}
			}

			if (this.infoScreen1.sprite != null) {
				this.infoScreen1.sprite.visible = (num == 1);
			}

			if (this.infoScreen2.sprite != null) {
				this.infoScreen2.sprite.visible = (num == 2);
			}

			if (this.infoScreen3.sprite != null) {
				this.infoScreen3.sprite.visible = (num == 3);
			}
		}

		private function setupLoaderMovie ():void {
			if (this.loaderMovie == null) {
				this.loaderMovie = new Sprite ();
				this.loaderMovie.addChild (new loaderMovieClass ());
			} else if (this.loaderMovie.parent != null) {
				this.removeChild (this.loaderMovie);
			}

			this.setupLoaderMoviePositions ();
			this.addChild (this.loaderMovie);
		}

		private function removeLoaderMovie ():void {
			if (this.loaderMovie != null) {
				if (this.loaderMovie.parent != null) {
					this.removeChild (this.loaderMovie);
				}
			}
		}

		private function setupLoaderMoviePositions ():void {
			if (this.loaderMovie != null) {
				this.loaderMovie.x = (this.stage.stageWidth - (this.loaderMovie.width == 0 ? 55 : this.loaderMovie.width)) / 2;
				this.loaderMovie.y = (this.stage.stageHeight - (this.loaderMovie.height == 0 ? 55 : this.loaderMovie.height)) / 2;
			}
		}

		private function setupCamera ():void {
			if (this.camera == null) {
				this.camera = Camera.getCamera ();
			}

			if (this.camera != null) {
				if (this.video == null) {
					this.video = new Video (this.stage.stageWidth, this.stage.stageHeight);
					this.setupVideoSize ();
					this.addChild (this.video);
				}
			} else {
				this.sendStatusMessage (Videorec.MSG_NO_CAMERA);
				Debug.fatal ('No camera available');
				return;
			}

			this.video.attachCamera (this.camera);
		}

		private function setupVideoSize ():void {
			if (this.camera != null) {
				this.camera.setMode (this.stage.stageWidth, this.stage.stageHeight, this.stage.frameRate);

				var width:Number = this.camera.width;
				var height:Number = this.camera.height;

				if (width > this.stage.stageWidth) {
					width = this.stage.stageWidth;
					height = (height / width) * this.stage.stageWidth;
				}

				if (height > this.stage.stageHeight) {
					height = this.stage.stageHeight;
					width = (width / height) * this.stage.stageHeight;
				}

				this.video.width = width;
				this.video.height = height;
				this.video.x = (this.stage.stageWidth - this.video.width) / 2;
				this.video.y = (this.stage.stageHeight - this.video.height) / 2;
			}
		}

		private function setupNetConnection ():void {
			this.connection = new NetConnection ();
			this.connection.addEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler, false, 0, true);
			this.connection.addEventListener (SecurityErrorEvent.SECURITY_ERROR, this.connectionSecurityErrorHandler, false, 0, true);
			this.connection.connect (this.connectionURL, this.sessionID);
		}

		private function setupNetStream ():void {
			this.stream = new NetStream (this.connection);

			if (
				this.buttonRecord.sprite != null &&
				(
					this.infoScreen1.sprite != null ||
					(
						this.infoScreen1.loader == null &&
						this.infoScreen1.sprite == null
					)
				)
			) {
				this.reset ();
			}
		}

		private function setupTimer ():void {
			if (this.recordTimer == null) {
				this.recordTimer = new Timer (1000, this.recordTime);
				this.recordTimer.addEventListener (TimerEvent.TIMER, this.recordTimerUpdateHandler, false, 0, false);
				this.recordTimer.addEventListener (TimerEvent.TIMER_COMPLETE, this.recordTimerCompleteHandler, false, 0, false);
				this.timerStatusText = new TextField ();
				this.timerStatusText.autoSize = TextFieldAutoSize.LEFT;
			} else if (this.timerStatusText.parent != null) {
				this.removeChild (this.timerStatusText);
			}

			this.setupTimerPositions ();
			this.addChild (this.timerStatusText);
			this.recordTimer.reset ();
			this.recordTimeLeft = this.recordTime;
			this.recordTimer.start ();
		}

		private function removeTimer ():void {
			if (this.recordTimer != null) {
				this.recordTimer.stop ();
			}

			if (this.timerStatusText != null) {
				if (this.timerStatusText.parent != null) {
					this.removeChild (this.timerStatusText);
				}
			}
		}

		private function setupTimerPositions ():void {
			if (this.timerStatusText != null && this.video != null) {
				this.timerStatusText.x = this.video.x;
				this.timerStatusText.y = this.stage.stageHeight - this.timerStatusText.height;
			}
		}

		private function sendStatusMessage (message:String):void {
			if (this.statusText == null) {
				this.statusText = new TextField ();
				this.statusText.autoSize = TextFieldAutoSize.LEFT;
			} else if (this.statusText.parent != null) {
				this.removeChild (this.statusText);
			}

			this.statusText.text = message;
			this.addChild (this.statusText);
		}

		private function removeStatusMessage ():void {
			if (this.statusText != null) {
				if (this.statusText.parent != null) {
					this.removeChild (this.statusText);
				}
			}
		}

		private function setupStatusMessagePositions ():void {
			if (this.statusText != null) {
				this.statusText.x = (this.stage.stageWidth - this.statusText.textWidth) / 2;
				if (this.loaderMovie != null) {
					this.statusText.y = this.loaderMovie.y + this.loaderMovie.height;
				} else {
					this.statusText.y = (this.stage.stageHeight - this.statusText.textHeight) / 2;
				}
			}
		}

		private function addLoaderListeners (dispatcher:IEventDispatcher):void {
			dispatcher.addEventListener (Event.COMPLETE, this.loaderCompleteHandler, false, 0, true);
			dispatcher.addEventListener (HTTPStatusEvent.HTTP_STATUS, this.loaderHttpStatusHandler, false, 0, true);
			dispatcher.addEventListener (IOErrorEvent.IO_ERROR, this.loaderIoErrorHandler, false, 0, true);
		}

		private function removeLoaderListeners (dispatcher:IEventDispatcher):void {
			dispatcher.removeEventListener (Event.COMPLETE, this.loaderCompleteHandler);
			dispatcher.removeEventListener (HTTPStatusEvent.HTTP_STATUS, this.loaderHttpStatusHandler);
			dispatcher.removeEventListener (IOErrorEvent.IO_ERROR, this.loaderIoErrorHandler);
		}

	}
}