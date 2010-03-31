package se.klandestino.red5.applications.simpleVideoRec;

import java.net.*;
import java.io.*;
import org.red5.logging.Red5LoggerFactory;
import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.IConnection;
import org.red5.server.api.IScope;
import org.red5.server.api.stream.IServerStream;
import org.slf4j.Logger;

public class Application extends ApplicationAdapter {

	private static String R5MC_CONSUME_URL = "http://red5missioncontrol.metahost.se/record/consume";

	private static Logger log = Red5LoggerFactory.getLogger (Application.class, "simpleVideoRec");

	private String streamName;

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
		log.info ("Connected with id " + conn.getClient ().getId () + " and stream name " + params [0]);

		if (params.length > 0) {
			if (this.checkStreamName ((String) params [0])) {
				this.streamName = (String) params [0];
			} else {
				returnVal = false;
			}
		}

		return returnVal;
	}

	public void appDisconnect (IConnection conn) {
		super.appDisconnect (conn);
		log.info ("Disconnected with " + conn.getClient ().getId ());
	}

	public String publish () {
		return "";
	}

	public boolean checkStreamName (String name) {
		try {
			URL url = new URL (R5MC_CONSUME_URL);
			URLConnection urlconn = url.openConnection ();
			HttpURLConnection httpconn = (HttpURLConnection) urlconn;

			httpconn.setDoOutput (true);
			httpconn.setDoInput (true);
			httpconn.setRequestMethod ("POST");

			OutputStream outstream = httpconn.getOutputStream ();
			Writer writeout = new OutputStreamWriter (outstream);

			writeout.write ("stream=" + name);
			writeout.flush ();
			writeout.close ();

			InputStream instream = httpconn.getInputStream ();
			StringBuffer result = new StringBuffer ();
			int c;

			while ((c = instream.read ()) != -1) result.append ((char) c);
			log.info ("R5MC Result: " + result.toString ());

			instream.close ();
			httpconn.disconnect ();

			if (result.toString ().indexOf ("<red5missioncontrol><consume /></red5missioncontrol>") > -1) {
				log.info ("R5MC got valid result, accept connection");
				return true;
			} else {
				log.error ("R5MC got no valid result, reject connection");
			}
		} catch (IOException error) {
			log.error ("R5MC Error: " + error);
		}

		return false;
	}

}