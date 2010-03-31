package se.klandestino.red5.applications.simpleVideoRec;

import java.net.*;
import java.io.*;
import java.util.HashMap;
import java.util.Map;
import org.red5.logging.Red5LoggerFactory;
import org.red5.server.adapter.ApplicationAdapter;
import org.red5.server.api.IConnection;
import org.red5.server.api.IScope;
import org.red5.server.api.stream.IServerStream;
import org.slf4j.Logger;

public class Application extends ApplicationAdapter {

	private static String CONF_FILE = "webapps/simpleVideoRec/WEB-INF/simpleVideoRec.conf";
	private static String STREAM_DIR = "webapps/simpleVideoRec/streams";

	private static Logger log = Red5LoggerFactory.getLogger (Application.class, "simpleVideoRec");

	private String publishDir;
	private int publishTime;
	private String publishURL;
	private String r5mcConsumeURL;
	private String streamName;

	public boolean appStart (IScope app) {
		boolean returnVal = super.appStart (app);
		log.info ("Application started");
		this.readConfig ();
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
		} else {
			returnVal = false;
		}

		return returnVal;
	}

	public void appDisconnect (IConnection conn) {
		super.appDisconnect (conn);
		log.info ("Disconnected with " + conn.getClient ().getId ());
	}

	public Map<String, Object> publish () {
		Map<String, Object> values = new HashMap<String, Object> ();

		try {
			File inputFile = new File (STREAM_DIR + "/" + this.streamName + ".flv");
			File outputFile = new File (this.publishDir + "/" + this.streamName + ".flv");

		    FileReader in = new FileReader (inputFile);
		    FileWriter out = new FileWriter (outputFile);
		    int c;

		    while ((c = in.read ()) != -1) {
				out.write (c);
			}

		    in.close ();
		    out.close ();

			log.info ("Copied file " + STREAM_DIR + "/" + this.streamName + ".flv to " + this.publishDir + "/" + this.streamName + ".flv");
		} catch (IOException error) {
			log.error ("Error while copying file: " + error);
			values.put ("error", error);
			return values;
		}

		values.put ("url", this.publishURL + "/" + this.streamName + ".flv");
		values.put ("time_left", (System.currentTimeMillis () / 1000) + this.publishTime);
		return values;
	}

	private boolean checkStreamName (String name) {
		try {
			URL url = new URL (this.r5mcConsumeURL);
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

	private void readConfig () {
		log.info ("Reading config file from " + CONF_FILE);

		try {
			FileInputStream fstream = new FileInputStream (CONF_FILE);
			DataInputStream instream = new DataInputStream (fstream);
			BufferedReader reader = new BufferedReader (new InputStreamReader(instream));
			String line;

			while ((line = reader.readLine ()) != null) {
				String [] match = line.split ("\\s*?:\\s*?", 2);

				if (match.length > 1) {
					match [0] = match [0].trim ();
					match [1] = match [1].trim ();

					if (match [0].equals ("publishDir")) {
						log.info ("Found publishDir as: " + match [1]);
						this.publishDir = match [1];
					} else if (match [0].equals ("publishTime")) {
						log.info ("Found publishTime as: " + match [1]);
						this.publishTime = Integer.parseInt (match [1]);
					} else if (match [0].equals ("publishURL")) {
						log.info ("Found publishURL as: " + match [1]);
						this.publishURL = match [1];
					} else if (match [0].equals ("r5mcConsumeURL")) {
						log.info ("Found r5mcConsumeURL as: " + match [1]);
						this.r5mcConsumeURL = match [1];
					} else {
						log.info ("Some non supported config line: " + match [0] + " | " + match [1]);
					}
				} else {
					log.info ("Syntax error in config line: " + line);
				}
			}

			instream.close ();
		} catch (Exception error) {
			log.error ("Error while reading config file: " + error.getMessage ());
		}
	}

}