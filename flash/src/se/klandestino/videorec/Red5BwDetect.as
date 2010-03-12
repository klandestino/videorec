package se.klandestino.videorec {

	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
	import org.red5.flash.bwcheck.ClientServerBandwidth;
	import org.red5.flash.bwcheck.ServerClientBandwidth;
	import org.red5.flash.bwcheck.events.BandwidthDetectEvent;
	import se.klandestino.flash.debug.Debug;

	/**
	 *	Class description.
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 9.0
	 *
	 *	@author spurge
	 *	@since  10.03.2010
	 */
	public class Red5BwDetect extends EventDispatcher implements IEventDispatcher {

		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------

		public static const CLIENT_SERVICE:String = 'bwCheckService.onClientBWCheck';
		public static const SERVER_SERVICE:String = 'bwCheckService.onServerClientBWCheck';

		//--------------------------------------
		//  CONSTRUCTOR
		//--------------------------------------

		/**
		 *	@constructor
		 */
		public function Red5BwDetect () {
			super ();
		}

		//--------------------------------------
		//  PRIVATE VARIABLES
		//--------------------------------------

		private var _connection:NetConnection;
		private var _deltaDown:Number = 0;
		private var _deltaUp:Number = 0;
		private var _detected:Boolean = false;
		private var _kbitDown:Number = 0;
		private var _kbitUp:Number = 0;
		private var _latency:Number = 0;
		private var clientServer:ClientServerBandwidth;
		private var serverClient:ServerClientBandwidth;

		//--------------------------------------
		//  GETTER/SETTERS
		//--------------------------------------

		public function get connection ():NetConnection {
			return this._connection;
		}

		public function set connection (connection:NetConnection):void {
			this.removeConnection ();
			this._connection = connection;
			this.setupConnection ();
		}

		public function get detected ():Boolean {
			return this._detected;
		}

		public function get deltaDown ():Number {
			return this._deltaDown;
		}

		public function get deltaUp ():Number {
			return this._deltaUp;
		}

		public function get kbitDown ():Number {
			return this._kbitDown;
		}

		public function get kbitUp ():Number {
			return this._kbitUp;
		}

		public function get latency ():Number {
			return this._latency;
		}

		//--------------------------------------
		//  PUBLIC METHODS
		//--------------------------------------

		public function start ():void {
			this._detected = false;
			this.startServerClient ();
		}

		public function stop ():void {
			this.stopServerClient ();
			this.stopClientServer ();
		}

		//--------------------------------------
		//  EVENT HANDLERS
		//--------------------------------------

		private function connectionNetStatusHandler (event:NetStatusEvent):void {
			if (event.info.code == 'NetConnection.Connect.Success') {
				this.start ();
			} else {
				this.stop ();
			}
		}

		public function detectFailedHandler (event:BandwidthDetectEvent):void {
			Debug.error ('Bandwidth detection failed with error: ' + event.info.application + ' ' + event.info.description);
			this.stop ();
			this.dispatchEvent (new ErrorEvent (ErrorEvent.ERROR));
		}

		public function clientCompleteHandler (event:BandwidthDetectEvent):void {			
			Debug.debug ('Client/Server detection complete – kbitUp = ' + event.info.kbitUp + ', deltaUp: ' + event.info.deltaUp + ', deltaTime: ' + event.info.deltaTime + ', latency: ' + event.info.latency + ', KBytes: ' + event.info.KBytes);
			this._kbitUp = event.info.kbitUp;
			this._deltaUp = event.info.deltaUp;
			this._latency = event.info.latency;
			this.stopClientServer ();
			this._detected = true;
			this.dispatchEvent (new Event (Event.COMPLETE));
		}
		
		public function clientStatusHandler (event:BandwidthDetectEvent):void {
			if (event.info != null) {
				Debug.debug ('Client/Server detection status – count: ' + event.info.count + ', sent: ' + event.info.sent + ', timePassed: ' + event.info.timePassed + ', latency: ' + event.info.latency + ', overhead: ' + event.info.overhead + ', packet interval: ' + event.info.pakInterval + ', cumLatency: ' + event.info.cumLatency);
			}
		}

		public function serverCompleteHandler (event:BandwidthDetectEvent):void {
			Debug.debug ('Server/Client detection complete – kbitDown: ' + event.info.kbitDown + ', deltaDown: ' + event.info.deltaDown + ', deltaTime: ' + event.info.deltaTime + ', latency: ' + event.info.latency);
			this._kbitDown = event.info.kbitDown;
			this._deltaDown = event.info.deltaDown;
			this._latency = event.info.latency;
			this.stopServerClient ();
			this.startClientServer ();
		}
		
		public function serverStatusHandler (event:BandwidthDetectEvent):void {
			if (event.info != null) {
				Debug.debug ('Server/Client detection status – count: ' + event.info.count + ', sent: ' + event.info.sent + ', timePassed: ' + event.info.timePassed + ', latency: ' + event.info.latency + ', cumLatency: ' + event.info.cumLatency);
			}
		}

		//--------------------------------------
		//  PRIVATE & PROTECTED INSTANCE METHODS
		//--------------------------------------

		private function setupConnection ():void {
			this._connection.addEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler, false, 0, true);

			if (this._connection.connected) {
				this.start ();
			}
		}

		private function removeConnection ():void {
			this.stop ();
			if (this._connection != null) {
				this._connection.removeEventListener (NetStatusEvent.NET_STATUS, this.connectionNetStatusHandler);
				this._connection = null;
			}
		}

		private function startClientServer ():void {
			this.clientServer  = new ClientServerBandwidth ();
			this.clientServer.connection = this._connection;
			this.clientServer.service = Red5BwDetect.CLIENT_SERVICE;
			this.clientServer.addEventListener (BandwidthDetectEvent.DETECT_COMPLETE, this.clientCompleteHandler, false, 0, true);
			this.clientServer.addEventListener (BandwidthDetectEvent.DETECT_STATUS, this.clientStatusHandler, false, 0, true);
			this.clientServer.addEventListener (BandwidthDetectEvent.DETECT_FAILED, this.detectFailedHandler, false, 0, true);
			this.clientServer.start ();
		}

		private function stopClientServer ():void {
			if (this.clientServer != null) {
				this.clientServer.connection = null;
				this.clientServer.removeEventListener (BandwidthDetectEvent.DETECT_COMPLETE, this.clientCompleteHandler);
				this.clientServer.removeEventListener (BandwidthDetectEvent.DETECT_STATUS, this.clientStatusHandler);
				this.clientServer.removeEventListener (BandwidthDetectEvent.DETECT_FAILED, this.detectFailedHandler);
			}

			this.clientServer = null;
		}

		private function startServerClient ():void {
			this.serverClient = new ServerClientBandwidth ();
			this.serverClient.connection = this._connection;
			this.serverClient.service = Red5BwDetect.SERVER_SERVICE;
			this.serverClient.addEventListener (BandwidthDetectEvent.DETECT_COMPLETE, this.serverCompleteHandler, false, 0, true);
			this.serverClient.addEventListener (BandwidthDetectEvent.DETECT_STATUS, this.serverStatusHandler, false, 0, true);
			this.serverClient.addEventListener (BandwidthDetectEvent.DETECT_FAILED, this.detectFailedHandler, false, 0, true);
			this.serverClient.start ();
		}

		private function stopServerClient ():void {
			if (this.serverClient != null) {
				this.serverClient.connection = null;
				this.serverClient.removeEventListener (BandwidthDetectEvent.DETECT_COMPLETE, this.serverCompleteHandler);
				this.serverClient.removeEventListener (BandwidthDetectEvent.DETECT_STATUS, this.serverStatusHandler);
				this.serverClient.removeEventListener (BandwidthDetectEvent.DETECT_FAILED, this.detectFailedHandler);
			}

			this.serverClient = null;
		}

	}
}