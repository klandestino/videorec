package {

	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.Stage;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.StatusEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.GlowFilter;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.Responder;
	import flash.net.URLRequest;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	import net.hires.debug.Stats;
	import org.red5.flash.bwcheck.events.BandwidthDetectEvent;
	import se.klandestino.flash.debug.Debug;
	import se.klandestino.flash.debug.loggers.NullLogger;
	import se.klandestino.flash.debug.loggers.TraceLogger;
	import se.klandestino.flash.events.MultiLoaderEvent;
	import se.klandestino.flash.events.NetStreamClientEvent;
	import se.klandestino.flash.net.NetStreamClient;
	import se.klandestino.flash.net.MultiLoader;
	import se.klandestino.flash.utils.LoaderInfoParams;
	import se.klandestino.flash.utils.StringUtil;
	import se.klandestino.videorec.R5MC;
	import se.klandestino.videorec.Red5BwDetect;

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

		public static const CALLBACK_ERROR:String = 'error';
		public static const CALLBACK_FINISH:String = 'finish';

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

		public static const FINISH_SERVICE:String = 'publish';

		public static const MSG_NO_CAMERA:String = 'No camera connected or available!';
		public static const MSG_NO_CONNECTION:String = 'Server connection failed!';
		public static const MSG_NO_MICROPHONE:String = 'No microphone connected or available!';
		public static const MSG_LOST_CONNECTION:String = 'You lost the connection to the server!';
		public static const MSG_SECURITY_ERROR:String = 'Server connection failed with a security error!';
		public static const MSG_STREAM_IO_ERROR:String = 'An input/output error occured while working with the network stream!';

		public static const MICROPHONE_GAIN:Number = 100;

		public static const SCREEN_INFO:int = 1;
		public static const SCREEN_PLAY:int = 2;
		public static const SCREEN_DONE:int = 3;

		public static const STREAM_BUFFER:int = 2;

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
		private var buttonFinish:Object;
		private var buttonsLoaded:Boolean = false;
		private var bwDetect:Red5BwDetect;
		private var camera:Camera;
		private var connected:Boolean = false;
		private var connection:NetConnection;
		private var currentInfoScreen:Object;
		private var currentInfoScreenNum:int = 0;
		private var finishResponder:Responder;
		private var infoScreen1:Object;
		private var infoScreen2:Object;
		private var infoScreen3:Object;
		private var jsCallback:String = null;
		private var loaderMovie:Sprite;
		private var microphone:Microphone;
		private var multiLoader:MultiLoader;
		private var missionControl:R5MC;
		private var r5mcProject:String = '';
		private var r5mcSecret:String = '';
		private var recordTime:int = 120;
		private var recordTimeLeft:int = 0;
		private var recordTimer:Timer;
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
			Debug.debug ('Trying to play recorded stream ' + this.missionControl.stream);
			this.setupNetStream ();
			this.removeInfoScreen ();
			this.setupLoaderMovie ();
			this.stream.bufferTime = Videorec.STREAM_BUFFER;
			this.stream.receiveVideo (true);
			this.stream.receiveAudio (true);

			var playSuccess:Boolean = false;
			try {
				this.stream.play (this.missionControl.stream);
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
			Debug.debug ('Trying to start recording ' + this.missionControl.stream);
			this.setupNetStream ();
			this.streamDuration = 0;
			this.removeInfoScreen ();
			this.setupLoaderMovie ();

			var recordSuccess:Boolean = false;
			try {
				this.stream.publish (this.missionControl.stream, 'record');
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
			Debug.debug ('Trying to stop recording or playing ' + this.missionControl.stream);
			this.removeTimer ();
			this.removeStopButton ();
			this.setupLoaderMovie ();
			this.stream.close ();
			this.removeNetStream ();
			this.setupVideoFilters ();
			this.camera.setLoopback (false);
			this.microphone.setLoopBack (false);
			this.video.attachNetStream (null);
			this.video.attachCamera (this.camera);

			if (!(this.streamActiveRecording)) {
				this.playStop ();
			}
		}

		public function finish ():void {
			/*Debug.debug ('Calling server to finish up with recorded material');

			this.removeInfoScreen ();
			this.setupLoaderMovie ();

			if (this.finishResponder == null) {
				this.finishResponder = new Responder (this.finishCallResultHandler, this.finishCallStatusHandler);
			}

			this.connection.call (Videorec.FINISH_SERVICE, this.finishResponder);*/

			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_DONE);
			this.sendCallback (Videorec.CALLBACK_FINISH, {
				http: this.missionControl.http,
				meta: this.missionControl.meta,
				time_left: this.missionControl.timeLeft
			});
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

		private function cameraStatusHandler (event:StatusEvent):void {
			Debug.debug ('Camera status: ' + event.code);

			switch (event.code) {
				case 'Camera.Unmuted':
					this.setupCamera ();

					if (this.missionControl.loaded && this.connected && this.buttonsLoaded && this.bwDetect.detected && !(this.microphone.muted)) {
						this.reset ();
					}
					break;
				case 'Camera.Muted':
					this.sendError (Videorec.MSG_NO_CAMERA);
					break;
			}
		}

		private function microphoneStatusHandler (event:StatusEvent):void {
			Debug.debug ('Microphone status: ' + event.code);

			switch (event.code) {
				case 'Microphone.Unmuted':
					this.setupCamera ();

					if (this.missionControl.loaded && this.connected && this.buttonsLoaded && this.bwDetect.detected && !(this.camera.muted)) {
						this.reset ();
					}
					break;
				case 'Microphone.Muted':
					this.sendError (Videorec.MSG_NO_MICROPHONE);
					break;
			}
		}

		private function loaderCompleteHandler (event:Event):void {
			Debug.debug ('All images loaded');

			this.multiLoader.removeEventListener (Event.COMPLETE, this.loaderCompleteHandler);
			this.multiLoader.removeEventListener (MultiLoaderEvent.ERROR, this.loaderErrorHandler);
			this.multiLoader.removeEventListener (MultiLoaderEvent.PART_LOADED, this.loaderPartHandler);
			this.multiLoader = null;

			this.buttonsLoaded = true;
			if (this.missionControl.loaded && this.connected && this.bwDetect.detected && !(this.camera.muted) && !(this.microphone.muted)) {
				this.reset ();
			}
		}

		private function loaderErrorHandler (event:MultiLoaderEvent):void {
			event.setProperties (null, null);
		}

		private function loaderPartHandler (event:MultiLoaderEvent):void {
			event.container.visible = false;
			this.addChild (event.container);
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

		private function buttonFinishClickHandler (event:MouseEvent):void {
			Debug.debug ('Finish button clicked');
			this.finish ();
		}

		private function recordTimerUpdateHandler (event:TimerEvent):void {
			this.recordTimeLeft--;
			this.updateTimer (this.recordTimeLeft);
		}

		private function recordTimerCompleteHandler (event:TimerEvent):void {
			Debug.debug ('Recording timer completed');
			this.stop ();
		}

		private function missionControlCompleteHandler (event:Event):void {
			Debug.debug ('Mission Control Complete');
			this.setupNetConnection ();
		}

		private function missionControlErrorHandler (event:ErrorEvent):void {
			Debug.debug ('Mission Control Error');
			this.sendError (Videorec.MSG_NO_CONNECTION);
		}

		private function connectionNetStatusHandler (event:NetStatusEvent): void {
			Debug.debug ('NetConnection status: ' + event.info.code);

			switch (event.info.code) {
				case 'NetConnection.Connect.Success':
					this.connected = true;
					if (this.buttonsLoaded && this.bwDetect.detected && !(this.camera.muted) && !(this.microphone.muted)) {
						this.reset ();
					}
					break;
				case 'NetConnection.Connect.Failed':
					this.connected = false;
					this.sendError (Videorec.MSG_NO_CONNECTION);
					break;
				case 'NetConnection.Connect.Closed':
					this.connected = false;
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
			Debug.debug ('NetStream meta');

			var key:String;
			for (key in event.info) {
				Debug.debug (key + ': ' + event.info [key]);
			}

			this.streamDuration = parseFloat (event.info.duration);
		}

		private function bwCheckCompleteHandler (event:Event):void {
			Debug.debug ('Bandwidth detection complete');

			if (this.buttonsLoaded && !(this.camera.muted) && !(this.microphone.muted)) {
				this.reset ();
			}
		}

		private function bwCheckFailedHandler (event:ErrorEvent):void {
			Debug.debug ('Bandwidth detection failed');
		}

		private function statusButtonClickHandler (event:MouseEvent):void {
			if (this.camera.muted || this.microphone.muted) {
				Security.showSettings (SecurityPanel.PRIVACY);
			}

			this.init ();
		}

		private function finishCallResultHandler (result:Object):void {
			var error:String, url:String, timeLeft:String;

			try {
				error = result.error;
			} catch (error:Error) {
				//
			}

			try {
				url = result.url;
			} catch (error:Error) {
				//
			}

			try {
				timeLeft = result.time_left;
			} catch (error:Error) {
				//
			}

			if (!(StringUtil.isEmpty (error))) {
				Debug.error ('Finish call returned with error: ' + error);
				this.removeLoaderMovie ();
				this.setupInfoScreen (Videorec.SCREEN_PLAY);
			} else if (!(StringUtil.isEmpty (url) && StringUtil.isEmpty (timeLeft))) {
				Debug.debug ('Finish call succeded, returning with finish callback');
				this.removeLoaderMovie ();
				this.setupInfoScreen (Videorec.SCREEN_DONE);
				this.sendCallback (Videorec.CALLBACK_FINISH, {url: url, time_left: timeLeft});
			} else {
				Debug.debug ('Finish call failed and no known data was returned');
				this.removeLoaderMovie ();
				this.setupInfoScreen (Videorec.SCREEN_PLAY);
			}
		}

		private function finishCallStatusHandler (status:Object):void {
			Debug.debug ('Finish call status: ' + status.code);

			if (status.code == 'NetConnection.Call.Failed') {
				Debug.error ('Finish call returned with error');
				this.removeLoaderMovie ();
				this.setupInfoScreen (Videorec.SCREEN_PLAY);
			}
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

			if (this.buttonFinish == null) {
				this.buttonFinish = new Object ();
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
			this.setupMicrophone ();
			this.setupVideoFilters ();
			this.setupLoaderMovie ();
			this.setupImages ();
			this.setupMissionControl ();

			// Visible memory statistics
			/*if (this.stats == null) {
				this.stats = new Stats ();
				this.addChild (this.stats);
			}*/
		}

		private function playStart ():void {
			Debug.debug ('Start playing recorded stream ' + this.missionControl.stream);
			this.removeLoaderMovie ();
			this.setupStopButton ();
			this.removeVideoFilters ();
			this.video.attachCamera (null);
			this.video.attachNetStream (this.stream);
		}

		private function playStop ():void {
			Debug.debug ('Stopped playing recorded stream ' + this.missionControl.stream);
			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_PLAY);
		}

		private function recordStart ():void {
			Debug.debug ('Start recording ' + this.missionControl.stream);
			this.removeLoaderMovie ();
			this.removeVideoFilters ();
			this.setupStopButton ();

			if (this.bwDetect.detected) {
				Debug.debug ('Setting camera bandwidth to ' + this.bwDetect.kbitUp + ' kbit');
				this.camera.setQuality (this.bwDetect.kbitUp, 0);
			}

			this.camera.setLoopback (true);
			//this.microphone.setLoopBack (true);
			this.stream.attachCamera (this.camera);
			this.stream.attachAudio (this.microphone);
			this.setupTimer ();
		}

		private function recordStop ():void {
			Debug.debug ('Stopped recording ' + this.missionControl.stream);
			this.removeLoaderMovie ();
			this.setupInfoScreen (Videorec.SCREEN_PLAY);
		}

		/**
		*	Gets the inserted parameters from the embedded player.
		*	<h4>Parameters:</h4>
		*	<ul>
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
		*		<li>finishsrc – finish button source</li>
		*		<li>finishx – finish button x coordinates</li>
		*		<li>finishy – finish button y coordinates</li>
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
			this.r5mcProject = LoaderInfoParams.getParam (this.loaderInfo, 'r5mcproject', this.r5mcProject);
			this.r5mcSecret = LoaderInfoParams.getParam (this.loaderInfo, 'r5mcsecret', this.r5mcSecret);
			this.recordTime = LoaderInfoParams.getParam (this.loaderInfo, 'recordtime', this.recordTime);
			this.jsCallback = LoaderInfoParams.getParam (this.loaderInfo, 'callback', '');
			this.timerStatusFont = LoaderInfoParams.getParam (this.loaderInfo, 'recordtimerfont', this.timerStatusFont);
			this.timerStatusSize = LoaderInfoParams.getParam (this.loaderInfo, 'recordtimersize', this.timerStatusSize);
			this.timerStatusBold = LoaderInfoParams.getParam (this.loaderInfo, 'recordtimerbold', this.timerStatusBold);
			this.buttonPlay.src = LoaderInfoParams.getParam (this.loaderInfo, 'playsrc', '');
			this.buttonPlay.x = LoaderInfoParams.getParam (this.loaderInfo, 'playx', '');
			this.buttonPlay.y = LoaderInfoParams.getParam (this.loaderInfo, 'playy', '');
			this.buttonRecord.src = LoaderInfoParams.getParam (this.loaderInfo, 'recordsrc', '');
			this.buttonRecord.x = LoaderInfoParams.getParam (this.loaderInfo, 'recordx', '');
			this.buttonRecord.y = LoaderInfoParams.getParam (this.loaderInfo, 'recordy', '');
			this.buttonStop.src = LoaderInfoParams.getParam (this.loaderInfo, 'stopsrc', '');
			this.buttonStop.x = LoaderInfoParams.getParam (this.loaderInfo, 'stopx', '');
			this.buttonStop.y = LoaderInfoParams.getParam (this.loaderInfo, 'stopy', '');
			this.buttonFinish.src = LoaderInfoParams.getParam (this.loaderInfo, 'finishsrc', '');
			this.buttonFinish.x = LoaderInfoParams.getParam (this.loaderInfo, 'finishx', '');
			this.buttonFinish.y = LoaderInfoParams.getParam (this.loaderInfo, 'finishy', '');
			this.infoScreen1.src = LoaderInfoParams.getParam (this.loaderInfo, 'info1src', '');
			this.infoScreen1.x = LoaderInfoParams.getParam (this.loaderInfo, 'info1x', '');
			this.infoScreen1.y = LoaderInfoParams.getParam (this.loaderInfo, 'info1y', '');
			this.infoScreen2.src = LoaderInfoParams.getParam (this.loaderInfo, 'info2src', '');
			this.infoScreen2.x = LoaderInfoParams.getParam (this.loaderInfo, 'info2x', '');
			this.infoScreen2.y = LoaderInfoParams.getParam (this.loaderInfo, 'info2y', '');
			this.infoScreen3.src = LoaderInfoParams.getParam (this.loaderInfo, 'info3src', '');
			this.infoScreen3.x = LoaderInfoParams.getParam (this.loaderInfo, 'info3x', '');
			this.infoScreen3.y = LoaderInfoParams.getParam (this.loaderInfo, 'info3y', '');
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
			this.multiLoader = new MultiLoader ();
			this.multiLoader.addEventListener (Event.COMPLETE, this.loaderCompleteHandler, false, 0, true);
			this.multiLoader.addEventListener (MultiLoaderEvent.ERROR, this.loaderErrorHandler, false, 0, true);
			this.multiLoader.addEventListener (MultiLoaderEvent.PART_LOADED, this.loaderPartHandler, false, 0, true);

			if (this.buttonPlay.sprite == null) {
				this.buttonPlay.sprite = new Sprite ();
				this.multiLoader.add (this.buttonPlay.src, 'play', this.buttonPlay.sprite);
			} else {
				Debug.debug ('Play button already loaded');
			}

			if (this.buttonRecord.sprite == null) {
				this.buttonRecord.sprite = new Sprite ();
				this.multiLoader.add (this.buttonRecord.src, 'record', this.buttonRecord.sprite);
			} else {
				Debug.debug ('Record button already loaded');
			}

			if (this.buttonStop.sprite == null) {
				this.buttonStop.sprite = new Sprite ();
				this.multiLoader.add (this.buttonStop.src, 'stop', this.buttonStop.sprite);
			} else {
				Debug.debug ('Stop button already loaded');
			}

			if (this.buttonFinish.sprite == null) {
				this.buttonFinish.sprite = new Sprite ();
				this.multiLoader.add (this.buttonFinish.src, 'finish', this.buttonFinish.sprite);
			} else {
				Debug.debug ('Finish button already loaded');
			}

			if (this.infoScreen1.sprite == null) {
				this.infoScreen1.sprite = new Sprite ();
				this.multiLoader.add (this.infoScreen1.src, 'info1', this.infoScreen1.sprite);
			} else {
				Debug.debug ('Info screen 1 already loaded');
			}

			if (this.infoScreen2.sprite == null) {
				this.infoScreen2.sprite = new Sprite ();
				this.multiLoader.add (this.infoScreen2.src, 'info2', this.infoScreen2.sprite);
			} else {
				Debug.debug ('Info screen 2 already loaded');
			}

			if (this.infoScreen3.sprite == null) {
				this.infoScreen3.sprite = new Sprite ();
				this.multiLoader.add (this.infoScreen3.src, 'info3', this.infoScreen3.sprite);
			} else {
				Debug.debug ('Info screen 3 already loaded');
			}

			this.multiLoader.load ();
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

			if (this.buttonFinish.sprite != null && isNaN (parseInt (this.buttonFinish.x)) && this.currentInfoScreenNum > 1) {
				width1 = this.buttonFinish.sprite.width;
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

			if (this.buttonFinish.sprite != null) {
				if (!isNaN (parseInt (this.buttonFinish.x))) {
					this.buttonFinish.sprite.x = parseInt (this.buttonFinish.x);
				} else if (!isNaN (parseInt (this.buttonFinish.y))) {
					this.buttonFinish.sprite.x = (this.stage.stageWidth - this.buttonFinish.sprite.width) / 2;
				} else {
					this.buttonFinish.sprite.x = (this.stage.stageWidth - totalWidth) / 2;
				}

				if (!isNaN (parseInt (this.buttonFinish.y))) {
					this.buttonFinish.sprite.y = parseInt (this.buttonFinish.y);
				} else if (this.currentInfoScreen != null) {
					this.buttonFinish.sprite.y = this.currentInfoScreen.sprite.y + this.currentInfoScreen.sprite.height;
				} else {
					this.buttonFinish.sprite.y = (this.stage.stageHeight - this.buttonFinish.sprite.height) / 2;
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

			if (this.buttonFinish.sprite != null) {
				this.buttonFinish.sprite.visible = false;
				this.buttonFinish.sprite.buttonMode = false;
				this.buttonFinish.sprite.removeEventListener (MouseEvent.CLICK, this.buttonFinishClickHandler);
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

			if (this.buttonFinish.sprite != null) {
				this.buttonFinish.sprite.visible = (num == 2);
				this.buttonFinish.sprite.buttonMode = (num == 2);
				this.buttonFinish.sprite.mouseChildren = false;
				if (num == 2) {
					this.buttonFinish.sprite.addEventListener (MouseEvent.CLICK, this.buttonFinishClickHandler, false, 0, false);
				} else {
					this.buttonFinish.sprite.removeEventListener (MouseEvent.CLICK, this.buttonFinishClickHandler);
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

				if (this.camera != null) {
					this.camera.addEventListener (StatusEvent.STATUS, this.cameraStatusHandler, false, 0, true);
				}
			}

			if (this.camera != null) {
				if (this.camera.muted) {
					Debug.debug ('Camera is muted');
					Security.showSettings (SecurityPanel.PRIVACY);
				} else {
					Debug.debug ('Camera is not muted');
				}

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

			if (!(this.camera.muted)) {
				this.video.attachCamera (this.camera);
			}
		}

		private function removeCamera ():void {
			this.video.visible = false;
		}

		private function setupVideoSize ():void {
			if (this.camera != null) {
				if (!(this.camera.muted)) {
					this.camera.setMode (this.stage.stageWidth, this.stage.stageHeight, this.stage.frameRate);
				}

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

				Debug.debug ('Video size ' + this.video.width + 'x' + this.video.height + ', position ' + this.video.x + 'x' + this.video.y);
			}
		}

		private function setupMicrophone ():void {
			if (this.microphone == null) {
				this.microphone = Microphone.getMicrophone ();

				if (this.microphone != null) {
					this.microphone.gain = Videorec.MICROPHONE_GAIN;
					this.microphone.setUseEchoSuppression (true);
					this.microphone.setSilenceLevel (0);
					this.microphone.addEventListener (StatusEvent.STATUS, this.microphoneStatusHandler, false, 0, true);
				}
			}

			if (this.microphone != null) {
				if (this.microphone.muted) {
					Debug.debug ('Microphone is muted');
					Security.showSettings (SecurityPanel.PRIVACY);
				} else {
					Debug.debug ('Microphone is not muted');
				}
			} else {
				Debug.fatal ('No microphone available');
				this.sendError (Videorec.MSG_NO_MICROPHONE);
				return;
			}
		}

		private function setupMissionControl ():void {
			Debug.debug ('Setting up Mission Control');

			if (this.missionControl == null) {
				this.missionControl = new R5MC ();
				this.missionControl.addEventListener (Event.COMPLETE, this.missionControlCompleteHandler, false, 0, true);
				this.missionControl.addEventListener (ErrorEvent.ERROR, this.missionControlErrorHandler, false, 0, true);
			}

			this.missionControl.load (this.r5mcProject, this.r5mcSecret);
		}

		private function setupNetConnection ():void {
			Debug.debug ('Setting up NetConnection');

			if (this.connection == null) {
				this.connection = new NetConnection ();
				this.connection.addEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler, false, 0, true);
				this.connection.addEventListener (SecurityErrorEvent.SECURITY_ERROR, this.connectionSecurityErrorHandler, false, 0, true);

				this.bwDetect = new Red5BwDetect ();
				this.bwDetect.addEventListener (Event.COMPLETE, this.bwCheckCompleteHandler, false, 0, true);
				this.bwDetect.addEventListener (ErrorEvent.ERROR, this.bwCheckFailedHandler, false, 0, true);
				this.bwDetect.connection = this.connection;
			}

			this.connection.connect (this.missionControl.rtmp, this.missionControl.stream);
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
			this.sendCallback (Videorec.CALLBACK_ERROR, {message: message});
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

		private function sendCallback (type:String, params:Object = null):void {
			if (!(StringUtil.isEmpty (this.jsCallback))) {
				Debug.debug ('Calling ' + this.jsCallback + ' as javascript callback with type ' + type);
				ExternalInterface.call (this.jsCallback, type, params);
			} else {
				Debug.debug ('No javascript callback to call to');
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

	}
}