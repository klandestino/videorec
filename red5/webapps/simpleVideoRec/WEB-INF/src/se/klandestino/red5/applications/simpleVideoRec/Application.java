package se.klandestino.red5.applications.simpleVideoRec;

import org.red5.logging.Red5LoggerFactory;
import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.IConnection;
import org.red5.server.api.IScope;
import org.red5.server.api.stream.IServerStream;
import org.slf4j.Logger;

public class Application extends ApplicationAdapter {

	private static Logger log = Red5LoggerFactory.getLogger (Application.class, "simpleVideoRec");

	public boolean appStart (IScope app) {
		boolean returnVal = super.appStart (app);
		log.info ("Application started");
		return returnVal;
	}

	public void appStop (IScope app) {
		super.appStop (app);
		log.info ("Application stopped");
	}

	public boolean appConnect (IConnection conn, Object [] params) {
		boolean returnVal = super.appConnect (conn, params);
		log.info ("Connected with " + conn.getClient ().getId ());
		return returnVal;
	}

	public void appDisconnect (IConnection conn) {
		super.appDisconnect (conn);
		log.info ("Disconnected with " + conn.getClient ().getId ());
	}

	public String publish () {
		return "";
	}

	public String auth (String key) {
		return "";
	}

}