package {

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
	import flash.filters.GlowFilter;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	import net.hires.debug.Stats;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.debug.loggers.NullLogger;
	import se.klandestino.flash.debug.loggers.TraceLogger;
	import se.klandestino.flash.events.NetStreamClientEvent;
	import se.klandestino.flash.media.NetStreamClient;
	import se.klandestino.flash.utils.StringUtil;

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

		public static const ERROR_BUTTON_BOLD:Boolean = true;
		public static const ERROR_BUTTON_COLOR:int = 0x0000FF;
		public static const ERROR_BUTTON_FONT:String = 'Helvetica';
		public static const ERROR_BUTTON_SIZE:int = 14;
		public static const ERROR_BUTTON_TEXT:String = 'reset';
		public static const ERROR_BUTTON_UNDERLINE:Boolean = true;

		public static const ERROR_MSG_BOLD:Boolean = true;
		public static const ERROR_MSG_COLOR:int = 0xFF0000;
		public static const ERROR_MSG_FONT:String = 'Helvetica';
		public static const ERROR_MSG_SIZE:int = 18;

		public static const MSG_NO_CAMERA:String = 'No camera connected or available!';
		public static const MSG_NO_CONNECTION:String = 'Server connection failed!';
		public static const MSG_NO_MICROPHONE:String = 'No microphone connected or available!';
		public static const MSG_LOST_CONNECTION:String = 'You lost the connection to the server!';
		public static const MSG_SECURITY_ERROR:String = 'Server connection failed with a security error!';
		public static const MSG_STREAM_IO_ERROR:String = 'An input/output error occured while working with the network stream!';

		public static const SCREEN_INFO:int = 1;
		public static const SCREEN_PLAY:int = 2;
		public static const SCREEN_DONE:int = 3;

		public static const STREAM_BUFFER:int = 5;

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
		private var buttonStop:Object;
		private var buttonUpload:Object;
		private var camera:Camera;
		private var connection:NetConnection;
		private var connectionURL:String = 'rtmp://88.80.16.137/simpleVideoRec';
		private var currentInfoScreen:Object;
		private var currentInfoScreenNum:int = 0;
		private var infoScreen1:Object;
		private var infoScreen2:Object;
		private var infoScreen3:Object;
		private var loaderMovie:Sprite;
		private var microphone:Microphone;
		private var recordTime:int = 120;
		private var recordTimeLeft:int = 0;
		private var recordTimer:Timer;
		private var sessionID:String = String (Math.random ()).split ('.')[1];
		private var stats:Stats;
		private var statusText:TextField;
		private var statusTextFormat:TextFormat;
		private var statusButton:Sprite;
		private var statusButtonText:TextField;
		private var statusButtonFormat:TextFormat;
		private var stream:NetStream;
		private var streamActivePlayback:Boolean = false;
		private var streamActiveRecording:Boolean = false;
		private var streamBufferFull:Boolean = false;
		private var streamClient:NetStreamClient;
		private var streamDuration:Number = 0;
		private var streamStoppedPlayback:Boolean = true;
		private var timerStatusBold:Boolean = true;
		private var timerStatusColor:int = 0xFFFFFF;
		private var timerStatusFont:String = 'Helvetica';
		private var timerStatusGlow:Boolean = true;
		private var timerStatusGlowColor:int = 0x000000;
		private var timerStatusText:TextField;
		private var timerStatusTextFormat:TextFormat;
		private var timerStatusSize:int = 18;
		private var video:Video;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function play ():void {
			Debug.debug ('Trying to play recorded stream ' + this.sessionID);
			this.setupNetStream ();
			this.removeInfoScreen ();
			this.setupLoaderMovie ();
			this.stream.bufferTime = Videorec.STREAM_BUFFER;
			this.stream.receiveVideo (true);
			this.stream.receiveAudio (true);

			var playSuccess:Boolean = false;
			try {
				this.stream.play (this.sessionID);
				playSuccess = true;
			} catch (error:Error) {
				//
			}

			if (!(playSuccess)) {
				Debug.error ('Could not play videostream');
				this.stop ();
				this.sendError (Videorec.MSG_LOST_CONNECTION);
				return;
			}
		}

		public function reset ():void {
			Debug.debug ('Resetting');
			this.removeLoaderMovie ();
			this.removeTimer ();
			this.removeStatusMessage ();
			this.removeStopButton ();
			this.setupCamera ();
			this.setupVideoFilters ();
			this.setupInfoScreen (Videorec.SCREEN_INFO);
		}

		public function record ():void {
			Debug.debug ('Tryint to start recording ' + this.sessionID);
			this.setupNetStream ();
			this.streamDuration = 0;
			this.removeInfoScreen ();
			this.setupLoaderMovie ();

			var recordSuccess:Boolean = false;
			try {
				this.stream.publish (this.sessionID, 'record');
				recordSuccess = true;
			} catch (error:Error) {
				//
			}

			if (!(recordSuccess)) {
				Debug.error ('Could not record videostream')
				this.stop ();
				this.recordStop ();
				this.sendError (Videorec.MSG_LOST_CONNECTION);
				return;
			}
		}

		public function stop ():void {
			Debug.debug ('Trying to stop recording or playing ' + this.sessionID);
			this.removeTimer ();
			this.removeStopButton ();
			this.setupLoaderMovie ();
			this.stream.receiveVideo (false);
			this.stream.receiveAudio (false);
			this.stream.close ();
			this.removeNetStream ();
			this.setupVideoFilters ();
			this.camera.setLoopback (false);
			this.video.attachNetStream (null);
			this.video.attachCamera (this.camera);

			if (!(this.streamActiveRecording)) {
				this.playStop ();
			}
		}

		public function upload ():void {
			Debug.debug ('Uploading recorded material');
			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_DONE);
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function stageResizeHandler (event:Event):void {
			Debug.debug ('Stage resize handling');
			this.setupVideoSize ();
			this.setupLoaderMoviePositions ();
			this.setupStatusMessagePositions ();
			this.setupStatusButtonPositions ();
			this.setupTimerPositions ();
			this.setupInfoScreensPositions ();
			this.setupButtonsPositions ();
			this.setupStopButtonPositions ();
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
				if (this.buttonStop.loader.contentLoaderInfo === event.target) {
					type = 'stop';
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
				case 'stop':
					Debug.debug ('Stop button loaded');
					this.buttonStop.sprite = new Sprite ();
					this.buttonStop.sprite.visible = false;
					this.buttonStop.sprite.addChild (this.buttonStop.loader.contentLoaderInfo.content);
					this.buttonStop.loader = null;
					this.addChild (this.buttonStop.sprite);
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
				this.buttonRecord.sprite != null &&
				(
					this.infoScreen1.sprite != null
					|| (
						this.stream != null &&
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

		private function buttonStopClickHandler (event:MouseEvent):void {
			Debug.debug ('Stop button clicked');
			this.stop ();
		}

		private function buttonUploadClickHandler (event:MouseEvent):void {
			Debug.debug ('Upload button clicked');
			this.upload ();
		}

		private function recordTimerUpdateHandler (event:TimerEvent):void {
			this.recordTimeLeft--;
			this.updateTimer (this.recordTimeLeft);
		}

		private function recordTimerCompleteHandler (event:TimerEvent):void {
			Debug.debug ('Recording timer completed');
			this.stop ();
		}

		private function connectionNetStatusHandler (event:NetStatusEvent): void {
			Debug.debug ('NetConnection status: ' + event.info.code);

			switch (event.info.code) {
				case 'NetConnection.Connect.Success':
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
					break;
				case 'NetConnection.Connect.Failed':
					this.sendError (Videorec.MSG_NO_CONNECTION);
					break;
				case 'NetConnection.Connect.Closed':
					this.sendError (Videorec.MSG_LOST_CONNECTION);
					break;
			}
		}

		private function connectionSecurityErrorHandler (event:SecurityErrorEvent): void {
			Debug.error ('NetConnection security error');
			this.sendError (Videorec.MSG_SECURITY_ERROR);
		}

		private function streamNetStatusHandler (event:NetStatusEvent):void {
			Debug.debug ('NetStream status: ' + event.info.code);

			switch (event.info.code) {
				case 'NetStream.Buffer.Empty':
					if (this.streamActivePlayback) {
						if (this.streamStoppedPlayback) {
							this.streamActivePlayback = false;
							Debug.debug ('NetStream stopped streaming and buffer completed');
							this.stop ();
						} else if (!(this.streamBufferFull)) {
							this.setupBuffering ();
						} else {
							Debug.debug ('NetStream buffer completed but the stream has not stopped yet');
						}
					}
					break;
				case 'NetStream.Buffer.Full':
					this.removeBuffering ();
					this.streamBufferFull = true;
					break;
				case 'NetStream.Play.Start':
					this.streamActivePlayback = true;
					this.streamStoppedPlayback = false;
					this.streamBufferFull = false;
					this.playStart ();
					break;
				case 'NetStream.Play.Stop':
					this.streamStoppedPlayback = true;
					if (this.streamDuration <= Videorec.STREAM_BUFFER) {
						this.streamActivePlayback = false;
						Debug.debug ('NetStream duration is shorter than buffer, stopping playback');
						this.stop ();
					}
					break;
				case 'NetStream.Record.Start':
					this.streamActiveRecording = true;
					this.recordStart ();
					break;
				case 'NetStream.Record.Stop':
					this.streamActiveRecording = false;
					this.recordStop ();
					break;
			}
		}

		private function streamIoErrorHandler (event:IOErrorEvent):void {
			Debug.error ('NetStream input/output error');
			this.sendError (Videorec.MSG_STREAM_IO_ERROR);
		}

		private function streamClientStatusHandler (event:NetStreamClientEvent):void {
			Debug.debug ('NetStream client status: ' + event.info.code);
		}

		private function streamClientMetaHandler (event:NetStreamClientEvent):void {
			Debug.debug ('NetStream meta: duration=' + event.info.duration + ' width=' + event.info.width + ' height=' + event.info.height + ' framerate=' + event.info.framerate);
			this.streamDuration = parseFloat (event.info.duration);
		}

		private function statusButtonClickHandler (event:MouseEvent):void {
			this.init ();
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function init (event:Event = null):void {
			Debug.debug ('Initializing');
			this.stage.removeEventListener (Event.RESIZE, this.init);
			this.stage.removeEventListener (Event.RESIZE, this.stageResizeHandler);
			this.stage.addEventListener (Event.RESIZE, this.stageResizeHandler, false, 0, true);

			if (this.buttonPlay == null) {
				this.buttonPlay = new Object ();
			}

			if (this.buttonRecord == null) {
				this.buttonRecord = new Object ();
			}

			if (this.buttonStop == null) {
				this.buttonStop = new Object ();
			}

			if (this.buttonUpload == null) {
				this.buttonUpload = new Object ();
			}

			if (this.infoScreen1 == null) {
				this.infoScreen1 = new Object ();
			}

			if (this.infoScreen2 == null) {
				this.infoScreen2 = new Object ();
			}

			if (this.infoScreen3 == null) {
				this.infoScreen3 = new Object ();
			}

			this.removeStatusMessage ();
			this.getParams ();
			this.setupCamera ();
			this.setupVideoFilters ();
			this.setupLoaderMovie ();
			this.setupImages ();
			this.setupNetConnection ();

			if (this.stats == null) {
				this.stats = new Stats ();
				this.addChild (this.stats);
			}
		}

		private function playStart ():void {
			Debug.debug ('Start playing recorded stream ' + this.sessionID);
			this.removeLoaderMovie ();
			this.setupStopButton ();
			this.removeVideoFilters ();
			this.video.attachCamera (null);
			this.video.attachNetStream (this.stream);
		}

		private function playStop ():void {
			Debug.debug ('Stopped playing recorded stream ' + this.sessionID);
			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_PLAY);
		}

		private function recordStart ():void {
			Debug.debug ('Start recording ' + this.sessionID);
			this.removeLoaderMovie ();
			this.removeVideoFilters ();
			this.setupStopButton ();
			this.camera.setLoopback (true);
			this.stream.attachCamera (this.camera);
			this.stream.attachAudio (this.microphone);
			this.setupTimer ();
		}

		private function recordStop ():void {
			Debug.debug ('Stopped recording ' + this.sessionID);
			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_PLAY);
		}

		/**
		*	Gets the inserted parameters from the embedded player.
		*	<h4>Parameters:</h4>
		*	<ul>
		*		<li>sessionid – session identification</li>
		*		<li>connectionurl – URL to rtmp-server</li>
		*		<li>recordtime – time used to record defined in seconds</li>
		*		<li>recordtimerfont – secord timer font</li>
		*		<li>recordtimersize – secord timer font size</li>
		*		<li>recordtimerbold – secord timer font bold (true/false)</li> 
		*		<li>recordsrc – record button source</li>
		*		<li>recordx – record button x coordinates</li>
		*		<li>recordy – record button y coordinates</li>
		*		<li>playsrc – play button source</li>
		*		<li>playx – play button x coordinates</li>
		*		<li>playy – play button y coordinates</li>
		*		<li>uploadsrc – upload button source</li>
		*		<li>uploadx – upload button x coordinates</li>
		*		<li>uploady – upload button y coordinates</li>
		*		<li>stopsrc – stop button source</li>
		*		<li>stopx – stop button x coordinates</li>
		*		<li>stopy – stop button y coordinates</li>
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
				RECORD TIMER FONT
			**/

			var timerStatusFont:String;

			try {
				if (this.loaderInfo.parameters.recordtimerfont != null) {
					timerStatusFont = this.loaderInfo.parameters.recordtimerfont;
				}
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (timerStatusFont))) {
				this.timerStatusFont = timerStatusFont;
				Debug.debug ('Record timer font found ' + this.timerStatusFont);
			} else {
				Debug.debug ('No record timer font found');
			}

			/**
				RECORD TIMER FONT SIZE
			**/

			var timerStatusSize:String;

			try {
				if (this.loaderInfo.parameters.recordtimersize != null) {
					timerStatusSize = this.loaderInfo.parameters.recordtimersize;
				}
			} catch (error:Error) {
				//
			}

			if (!(isNaN (parseInt (timerStatusSize)))) {
				this.timerStatusSize = parseInt (timerStatusSize);
				Debug.debug ('Record timer font size found ' + this.timerStatusSize);
			} else if (!(StringUtil.isEmpty (timerStatusSize))) {
				Debug.warn ('Record timer font size was not an integer ' + timerStatusSize);
			} else {
				Debug.debug ('No record timer font size found');
			}

			/**
				RECORD TIMER FONT BOLD
			**/

			var timerStatusBold:String;

			try {
				if (this.loaderInfo.parameters.recordtimerbold != null) {
					timerStatusBold = this.loaderInfo.parameters.recordtimerbold;
				}
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (timerStatusBold))) {
				this.timerStatusBold = StringUtil.isTrue (timerStatusBold);
				Debug.debug ('Record timer font bold found ' + this.timerStatusBold);
			} else {
				Debug.debug ('No record timer font bold found');
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
				STOP BUTTON
			**/

			var buttonStop:Object = new Object ();

			try {
				buttonStop.src = this.loaderInfo.parameters.stopsrc;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonStop.src))) {
				this.buttonStop.src = buttonStop.src;
				Debug.debug ('Stop button source found ' + this.buttonStop.src);
			} else {
				Debug.warn ('No stop button source found');
			}

			try {
				buttonStop.x = this.loaderInfo.parameters.stopx;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonStop.x))) {
				this.buttonStop.x = buttonStop.x;
				Debug.debug ('Stop button x found ' + this.buttonStop.x);
			} else {
				Debug.debug ('No stop button x found');
			}

			try {
				buttonStop.y = this.loaderInfo.parameters.stopy;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (buttonStop.y))) {
				this.buttonStop.y = buttonStop.y;
				Debug.debug ('Stop button y found ' + this.buttonStop.y);
			} else {
				Debug.debug ('No stop button y found');
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

		private function setupVideoFilters ():void {
			var filters:Array = new Array ();
			filters.push (new BlurFilter (this.blur, this.blur, BitmapFilterQuality.HIGH));
			this.video.filters = filters;
		}

		private function removeVideoFilters ():void {
			this.video.filters = null;
		}

		private function setupImages ():void {
			if (this.buttonPlay.sprite == null) {
				if (!(StringUtil.isEmpty (this.buttonPlay.src))) {
					Debug.debug ('Loading play button');
					this.buttonPlay.loader = new Loader ();
					this.addLoaderListeners (this.buttonPlay.loader.contentLoaderInfo);
					this.buttonPlay.loader.load (new URLRequest (this.buttonPlay.src));
				} else {
					Debug.warn ('No play button to load');
				}
			} else {
				Debug.debug ('Play button already loaded');
			}

			if (this.buttonRecord.sprite == null) {
				if (!(StringUtil.isEmpty (this.buttonRecord.src))) {
					Debug.debug ('Loading record button');
					this.buttonRecord.loader = new Loader ();
					this.addLoaderListeners (this.buttonRecord.loader.contentLoaderInfo);
					this.buttonRecord.loader.load (new URLRequest (this.buttonRecord.src));
				} else {
					Debug.warn ('No record button to load');
				}
			} else {
				Debug.debug ('Record button already loaded');
			}

			if (this.buttonStop.sprite == null) {
				if (!(StringUtil.isEmpty (this.buttonStop.src))) {
					Debug.debug ('Loading stop button');
					this.buttonStop.loader = new Loader ();
					this.addLoaderListeners (this.buttonStop.loader.contentLoaderInfo);
					this.buttonStop.loader.load (new URLRequest (this.buttonStop.src));
				} else {
					Debug.warn ('No stop button to load');
				}
			} else {
				Debug.debug ('Stop button already loaded');
			}

			if (this.buttonUpload.sprite == null) {
				if (!(StringUtil.isEmpty (this.buttonUpload.src))) {
					Debug.debug ('Loading upload button');
					this.buttonUpload.loader = new Loader ();
					this.addLoaderListeners (this.buttonUpload.loader.contentLoaderInfo);
					this.buttonUpload.loader.load (new URLRequest (this.buttonUpload.src));
				} else {
					Debug.warn ('No upload button to load');
				}
			} else {
				Debug.debug ('Upload button already loaded');
			}

			if (this.infoScreen1.sprite == null) {
				if (!(StringUtil.isEmpty (this.infoScreen1.src))) {
					Debug.debug ('Loading info screen 1');
					this.infoScreen1.loader = new Loader ();
					this.addLoaderListeners (this.infoScreen1.loader.contentLoaderInfo);
					this.infoScreen1.loader.load (new URLRequest (this.infoScreen1.src));
				} else {
					Debug.warn ('No info screen 1 to load');
				}
			} else {
				Debug.debug ('Info screen 1 already loaded');
			}

			if (this.infoScreen2.sprite == null) {
				if (!(StringUtil.isEmpty (this.infoScreen2.src))) {
					Debug.debug ('Loading info screen 2');
					this.infoScreen2.loader = new Loader ();
					this.addLoaderListeners (this.infoScreen2.loader.contentLoaderInfo);
					this.infoScreen2.loader.load (new URLRequest (this.infoScreen2.src));
				} else {
					Debug.debug ('No info screen 2 to load');
				}
			} else {
				Debug.debug ('Info screen 2 already loaded');
			}

			if (this.infoScreen3.sprite == null) {
				if (!(StringUtil.isEmpty (this.infoScreen3.src))) {
					Debug.debug ('Loading info screen 3');
					this.infoScreen3.loader = new Loader ();
					this.addLoaderListeners (this.infoScreen3.loader.contentLoaderInfo);
					this.infoScreen3.loader.load (new URLRequest (this.infoScreen3.src));
				} else {
					Debug.debug ('No info screen 3 to load');
				}
			} else {
				Debug.debug ('Info screen 3 already loaded');
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

		private function setupStopButton ():void {
			if (this.buttonStop.sprite != null) {
				this.buttonStop.sprite.visible = true;
				this.buttonStop.sprite.buttonMode = true;
				this.buttonStop.sprite.mouseChildren = false;
				this.buttonStop.sprite.addEventListener (MouseEvent.CLICK, this.buttonStopClickHandler, false, 0, false);
			}

			this.setupStopButtonPositions ();
		}

		private function removeStopButton ():void {
			if (this.buttonStop.sprite != null) {
				this.buttonStop.sprite.visible = false;
				this.buttonStop.sprite.buttonMode = false;
				this.buttonStop.sprite.removeEventListener (MouseEvent.CLICK, this.buttonStopClickHandler);
			}
		}

		private function setupStopButtonPositions ():void {
			if (this.buttonStop.sprite != null) {
				if (!isNaN (parseInt (this.buttonStop.x))) {
					this.buttonStop.sprite.x = parseInt (this.buttonStop.x);
				} else {
					this.buttonStop.sprite.x = 0;
				}

				if (!isNaN (parseInt (this.buttonStop.y))) {
					this.buttonStop.sprite.y = parseInt (this.buttonStop.y);
				} else {
					this.buttonStop.sprite.y = this.stage.stageHeight - this.buttonStop.sprite.height;
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
				}
			} else {
				Debug.fatal ('No camera available');
				this.sendError (Videorec.MSG_NO_CAMERA);
				return;
			}

			if (this.video.parent == null) {
				this.addChild (this.video);
			}

			this.video.visible = true;
			this.setupVideoSize ();
			this.video.attachCamera (this.camera);
		}

		private function removeCamera ():void {
			this.video.visible = false;
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

		private function setupMicrophone ():void {
			if (this.microphone == null) {
				this.microphone = Microphone.getMicrophone ();
			}

			if (this.microphone == null) {
				Debug.fatal ('No microphone available');
				this.sendError (Videorec.MSG_NO_MICROPHONE);
				return;
			}
		}

		private function setupNetConnection ():void {
			Debug.debug ('Setting up NetConnection');

			if (this.connection == null) {
				this.connection = new NetConnection ();
				this.connection.addEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler, false, 0, true);
				this.connection.addEventListener (SecurityErrorEvent.SECURITY_ERROR, this.connectionSecurityErrorHandler, false, 0, true);
			}

			this.connection.connect (this.connectionURL, this.sessionID);
		}

		private function setupNetStream ():void {
			Debug.debug ('Setting up NetStream');

			this.removeNetStream ();

			this.stream = new NetStream (this.connection);
			this.stream.addEventListener (NetStatusEvent.NET_STATUS, this.streamNetStatusHandler, false, 0, true);
			this.stream.addEventListener (IOErrorEvent.IO_ERROR, this.streamIoErrorHandler, false, 0, true);

			if (this.streamClient == null) {
				this.streamClient = new NetStreamClient ();
				this.streamClient.addEventListener (NetStreamClientEvent.META, this.streamClientMetaHandler, false, 0, true);
				this.streamClient.addEventListener (NetStreamClientEvent.PLAY_STATUS, this.streamClientStatusHandler, false, 0, true);
			}

			this.stream.client = this.streamClient;
		}

		private function removeNetStream ():void {
			if (this.stream != null) {
				this.removeEventListener (NetStatusEvent.NET_STATUS, this.streamNetStatusHandler);
				this.removeEventListener (IOErrorEvent.IO_ERROR, this.streamIoErrorHandler);
				this.stream = null;
			}
		}

		private function setupTimer ():void {
			if (this.recordTimer == null) {
				this.recordTimer = new Timer (1000, this.recordTime);
				this.recordTimer.addEventListener (TimerEvent.TIMER, this.recordTimerUpdateHandler, false, 0, false);
				this.recordTimer.addEventListener (TimerEvent.TIMER_COMPLETE, this.recordTimerCompleteHandler, false, 0, false);
				this.timerStatusText = new TextField ();
				this.timerStatusText.selectable = false;
				this.timerStatusText.autoSize = TextFieldAutoSize.LEFT;
				this.timerStatusTextFormat = new TextFormat ();
				this.timerStatusTextFormat.bold = this.timerStatusBold;
				this.timerStatusTextFormat.color = this.timerStatusColor;
				this.timerStatusTextFormat.font = this.timerStatusFont;
				this.timerStatusTextFormat.size = this.timerStatusSize;
				this.timerStatusText.defaultTextFormat = this.timerStatusTextFormat;
				if (this.timerStatusGlow) {
					this.timerStatusText.filters = new Array ();
					this.timerStatusText.filters.push (new GlowFilter (this.timerStatusGlowColor));
				}
			} else if (this.timerStatusText.parent != null) {
				this.removeChild (this.timerStatusText);
			}

			this.setupTimerPositions ();
			this.addChild (this.timerStatusText);
			this.recordTimeLeft = this.recordTime;
			this.updateTimer (this.recordTime);
			this.recordTimer.reset ();
			this.recordTimer.start ();
		}

		private function updateTimer (time:int):void {
			var min:int = Math.floor (time / 60);
			var sec:int = time - (min * 60);
			this.timerStatusText.text = (min < 10 ? '0' : '') + min + ':' + (sec < 10 ? '0' : '') + sec;
			this.setupTimerPositions ();
		}

		private function removeTimer ():void {
			if (this.recordTimer != null) {
				this.recordTimer.stop ();
				this.recordTimer.reset ();
			}

			if (this.timerStatusText != null) {
				if (this.timerStatusText.parent != null) {
					this.removeChild (this.timerStatusText);
				}
			}
		}

		private function setupTimerPositions ():void {
			if (this.timerStatusText != null && this.video != null) {
				this.timerStatusText.x = this.video.x + this.video.width - this.timerStatusText.width;
				this.timerStatusText.y = this.video.y + this.video.height - this.timerStatusText.height;
			}
		}

		private function sendError (message:String):void {
			this.removeLoaderMovie ();
			this.removeTimer ();
			this.removeStatusMessage ();
			this.removeCamera ();
			this.removeInfoScreen ();
			this.removeStopButton ();
			this.sendStatusMessage (message);
			this.setupStatusButton ();
			Debug.error (message);
		}

		private function sendStatusMessage (message:String):void {
			if (this.statusText == null) {
				this.statusText = new TextField ();
				this.statusText.autoSize = TextFieldAutoSize.LEFT;
				this.statusTextFormat = new TextFormat ();
				this.statusTextFormat.bold = Videorec.ERROR_MSG_BOLD;
				this.statusTextFormat.color = Videorec.ERROR_MSG_COLOR;
				this.statusTextFormat.font = Videorec.ERROR_MSG_FONT;
				this.statusTextFormat.size = Videorec.ERROR_MSG_SIZE;
				this.statusText.defaultTextFormat = this.statusTextFormat;
			} else if (this.statusText.parent != null) {
				this.removeChild (this.statusText);
			}

			this.statusText.text = message;
			this.setupStatusMessagePositions ();
			this.addChild (this.statusText);
		}

		private function removeStatusMessage ():void {
			if (this.statusText != null) {
				if (this.statusText.parent != null) {
					this.removeChild (this.statusText);
				}
			}

			this.removeStatusButton ();
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

		private function setupStatusButton ():void {
			if (this.statusButton == null) {
				this.statusButton = new Sprite ();
				this.statusButtonText = new TextField ();
				this.statusButton.addChild (this.statusButtonText);
				this.statusButtonText.autoSize = TextFieldAutoSize.LEFT;
				this.statusButtonFormat = new TextFormat ();
				this.statusButtonFormat.bold = Videorec.ERROR_BUTTON_BOLD;
				this.statusButtonFormat.color = Videorec.ERROR_BUTTON_COLOR;
				this.statusButtonFormat.font = Videorec.ERROR_BUTTON_FONT;
				this.statusButtonFormat.size = Videorec.ERROR_BUTTON_SIZE;
				this.statusButtonFormat.underline = Videorec.ERROR_BUTTON_UNDERLINE;
				this.statusButtonText.defaultTextFormat = this.statusButtonFormat;
				this.statusButtonText.text = Videorec.ERROR_BUTTON_TEXT;
				this.statusButton.mouseChildren = false;
				this.statusButton.buttonMode = true;
			} else if (this.statusButton.parent != null) {
				this.removeChild (this.statusButton);
			}

			this.setupStatusButtonPositions ();
			this.statusButton.addEventListener (MouseEvent.CLICK, this.statusButtonClickHandler, false, 0, false);
			this.addChild (this.statusButton);
		}

		private function setupStatusButtonPositions ():void {
			if (this.statusButton != null && this.statusText != null) {
				this.statusButton.x = (this.stage.stageWidth - this.statusButtonText.textWidth) / 2;
				this.statusButton.y = this.statusText.y + this.statusText.height;
			}
		}

		private function removeStatusButton ():void {
			if (this.statusButton != null) {
				if (this.statusButton.parent != null) {
					this.removeChild (this.statusButton);
				}
				this.statusButton.removeEventListener (MouseEvent.CLICK, this.statusButtonClickHandler);
			}
		}

		private function setupBuffering ():void {
			this.setupVideoFilters ();
			this.setupLoaderMovie ();
		}

		private function removeBuffering ():void {
			this.removeLoaderMovie ();
			this.removeVideoFilters ();
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