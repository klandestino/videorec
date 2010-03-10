package se.klandestino.red5.applications.simpleVideoRec;

import org.red5.logging.Red5LoggerFactory;
import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.IConnection;
import org.slf4j.Logger;

public class Application extends ApplicationAdapter {

	private static Logger log = Red5LoggerFactory.getLogger (Application.class, "simpleVideoRec");

	public boolean appStart () {
		log.debug ("Application started");
		return true;
	}

	public void appStop () {
		log.debug ("Application stopped");
	}

	public boolean appConnect (IConnection conn, Object [] params) {
		log.debug ("Connected with " + conn.getClient ().getId ());
		return true;
	}

	public void appDisconnect (IConnection conn) {
		log.debug ("Disconnected with " + conn.getClient ().getId ());
		super.appDisconnect (conn);
	}

}