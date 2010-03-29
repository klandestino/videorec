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

		public static const R5MC_SECRET:String = 'videorec';
		public static const R5MC_URL:String = 'http://red5missioncontrol.metahost.se/record';

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

		private var _loaded:Boolean = false;
		private var _stream:String;
		private var loader:URLLoader;
		private var request:URLRequest;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get loaded ():Boolean {
			return this._loaded;
		}

		public function get stream ():String {
			return this._stream;
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function load ():void {
			this._loaded = false;
			this.setupLoader ();

			this.request = new URLRequest (R5MC_URL);
			this.request.method = URLRequestMethod.POST;
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
				if (xml.name ().localName == 'red5missioncontrol' && xml.attribute ('stream') != null) {
					this.success (xml.attribute ('stream').toString ());
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
				this.error ('Loader got http error ' + event.status);
			}
		}

		private function loaderIoErrorHandler (event:IOErrorEvent):void {
			this.error ('Loader got input/output error');
		}

		private function loaderSecurityErrorHandler (event:SecurityErrorEvent):void {
			this.error ('Loader got security error');
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function error (error:String):void {
			Debug.error (error);
			this.dispatchEvent (new ErrorEvent (ErrorEvent.ERROR));
			this.destroy ();
		}

		private function success (stream:String):void {
			Debug.debug ('Mission Control succeeded with stream: ' + stream);
			this._stream = stream;
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