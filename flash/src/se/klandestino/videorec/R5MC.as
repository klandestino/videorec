package se.klandestino.videorec {

	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import se.klandestino.flash.debug.Debug;

	/**
	 *	Class description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 9.0
	 *
	 *	@author spurge
	 *	@since  29.03.2010
	 */
	public class R5MC extends EventDispatcher implements IEventDispatcher {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		//public static const R5MC_URL:String = 'http://localhost:8080/record';
		public static const R5MC_URL:String = 'http://red5missioncontrol.metahost.se/record';
		public static const NETWORK_RETRIES:int = 3;
		public static const NETWORK_RETRY_TIMEOUT:int = 200;

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function R5MC () {
			super ();
		}

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var _http:String;
		private var _loaded:Boolean = false;
		private var _meta:String;
		private var _rtmp:String;
		private var _stream:String;
		private var _timeLeft:String;
		private var loader:URLLoader;
		private var project:String;
		private var request:URLRequest;
		private var retries:int = 0;
		private var retryTimeout:int;
		private var secret:String;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get http ():String {
			return this._http;
		}

		public function get loaded ():Boolean {
			return this._loaded;
		}

		public function get meta ():String {
			return this._meta;
		}

		public function get rtmp ():String {
			return this._rtmp;
		}

		public function get stream ():String {
			return this._stream;
		}

		public function get timeLeft ():String {
			return this._timeLeft;
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function load (project:String, secret:String, resetRetries:Boolean = true):void {
			this._loaded = false;
			this.setupLoader ();

			if (resetRetries) {
				this.retries = 0;
			}

			this.project = project;
			this.secret = secret;

			this.request = new URLRequest (R5MC_URL);
			this.request.method = URLRequestMethod.POST;
			var data:URLVariables = new URLVariables ();
			data.project = project;
			data.secret = secret;
			this.request.data = data;
			var success:Boolean = false;

			try {
				this.loader.load (this.request);
				success = true;
			} catch (error:Error) {
				//
			}

			if (!(success)) {
				this.error ('Failed to load');
			}
		}

		public function retry ():Boolean {
			clearTimeout (this.retryTimeout);

			if (this.retries < R5MC.NETWORK_RETRIES) {
				this.retries++;
				Debug.debug ('Retrying to load, ' + this.retries + ' of ' + R5MC.NETWORK_RETRIES);
				this.retryTimeout = setTimeout (this.load, R5MC.NETWORK_RETRY_TIMEOUT, this.project, this.secret, false);
				return true;
			}

			return false;
		}

		public function destroy ():void {
			this.loader.removeEventListener (Event.COMPLETE, this.loaderCompleteHandler);
			this.loader.removeEventListener (HTTPStatusEvent.HTTP_STATUS, this.loaderHttpStatusHandler);
			this.loader.removeEventListener (IOErrorEvent.IO_ERROR, this.loaderIoErrorHandler);
			this.loader.removeEventListener (SecurityErrorEvent.SECURITY_ERROR, this.loaderSecurityErrorHandler);
			this.loader = null;
			this.request = null;
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function loaderCompleteHandler (event:Event):void {
			Debug.debug ('Loader responded with: ' + this.loader.data);

			var xml:XML;

			try {
				xml = XML (this.loader.data);
			} catch (error:Error) {
				//
			}

			if (xml != null) {
				if (xml.name ().localName == 'red5missioncontrol' && xml.child ('record').length () > 0) {
					if (
						xml.child ('record') [0].attribute ('http').length () > 0 &&
						xml.child ('record') [0].attribute ('meta').length () > 0 &&
						xml.child ('record') [0].attribute ('rmtp').length () > 0 &&
						xml.child ('record') [0].attribute ('stream').length () > 0 &&
						xml.child ('record') [0].attribute ('time_left').length () > 0
					) {
						this._http = xml.child ('record') [0].attribute ('http').toString ();
						this._meta = xml.child ('record') [0].attribute ('meta').toString ();
						this._rtmp = xml.child ('record') [0].attribute ('rmtp').toString ();
						this._stream = xml.child ('record') [0].attribute ('stream').toString ();
						this._timeLeft = xml.child ('record') [0].attribute ('time_left').toString ();
						Debug.debug ("Parsed response data:\nhttp: " + this._http + "\nmeta: " + this._meta + "\nrtmp: " + this._rtmp + "\n stream: " + this._stream + "\ntimeLeft: " + this._timeLeft);
						this.success ();
					} else {
						this.error ('The XML had no stream and url defined');
					}
				} else {
					if (xml.attribute ('error') != null) {
						this.error ('Mission Control returned with error: ' + xml.attribute ('error').toString ());
					} else {
						this.error ('The XML response was not what we expected');
					}
				}
			} else {
				this.error ('No valid XML in response');
			}
		}

		private function loaderHttpStatusHandler (event:HTTPStatusEvent):void {
			if (event.status >= 400) {
				if (!this.retry ()) {
					this.error ('Loader got http error ' + event.status);
				}
			}
		}

		private function loaderIoErrorHandler (event:IOErrorEvent):void {
			if (!this.retry ()) {
				this.error ('Loader got input/output error');
			}
		}

		private function loaderSecurityErrorHandler (event:SecurityErrorEvent):void {
			if (!this.retry ()) {
				this.error ('Loader got security error');
			}
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function error (error:String):void {
			Debug.error (error);
			this.dispatchEvent (new ErrorEvent (ErrorEvent.ERROR));
			this.destroy ();
		}

		private function success ():void {
			Debug.debug ('Mission Control succeeded');
			this._loaded = true;
			this.dispatchEvent (new Event (Event.COMPLETE));
			this.destroy ();
		}

		private function setupLoader ():void {
			if (this.loader == null) {
				this.loader = new URLLoader ();
				this.loader.addEventListener (Event.COMPLETE, this.loaderCompleteHandler, false, 0, true);
				this.loader.addEventListener (SecurityErrorEvent.SECURITY_ERROR, this.loaderSecurityErrorHandler, false, 0, true);
				this.loader.addEventListener (HTTPStatusEvent.HTTP_STATUS, this.loaderHttpStatusHandler, false, 0, true);
				this.loader.addEventListener (IOErrorEvent.IO_ERROR, this.loaderIoErrorHandler, false, 0, true);
			}
		}

	}
}