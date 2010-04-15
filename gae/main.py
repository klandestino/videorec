from google.appengine.api import memcache
from google.appengine.api.labs import taskqueue
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp import template
from google.appengine.ext.webapp.util import run_wsgi_app
import os
import random
import string
import time

class Project(db.Model):
	name = db.StringProperty()
	secret = db.StringProperty()

class Recording(db.Model):
	project = db.StringProperty()
	onetimecode = db.StringProperty()
	created = db.DateTimeProperty(auto_now_add = True)

class CronJobEveryMinute(webapp.RequestHandler):
	def get(self):

		# Add cleanup task to servers queue
		q = taskqueue.Queue('servers')
		q.add(taskqueue.Task(
			params = {
				'cleanup': 120,
				}
			))

class CrossDomainPolicy(webapp.RequestHandler):
	def get(self):
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<!DOCTYPE cross-domain-policy SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">\r\n');
		self.response.out.write('<cross-domain-policy>');

		projects = db.GqlQuery('SELECT * FROM Project').fetch(200);
		for project in projects:
			self.response.out.write('<allow-access-from domain="' + project.name + '" />');
			self.response.out.write('<allow-access-from domain="www.' + project.name + '" />');
		self.response.out.write('</cross-domain-policy>');

	def post(self):
		self.get()

class Error(webapp.RequestHandler):
	def get(self):
		self.post()
	
	def post(self):
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<red5missioncontrol error="Unknown URL"></red5missioncontrol>');

class PostRequest(webapp.RequestHandler):
	def get(self):
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<red5missioncontrol error="HTTP POST request required"></red5missioncontrol>');

	def authorized(self):

		if not self.request.POST.has_key('project'):
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No project name given"></red5missioncontrol>');
			return False

		if not self.request.POST.has_key('secret'):
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No project secret given"></red5missioncontrol>');
			return False

		query = db.GqlQuery('SELECT * FROM Project WHERE name = :1 LIMIT 1', self.request.POST['project'])
		project = query.get()

		if project == None:
			project = Project()
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="Unknown project name and/or project secret"></red5missioncontrol>');
			return False

		if self.request.POST['secret'] == '':
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="Empty secret is not allowed"></red5missioncontrol>');
			return False

		if project.secret != self.request.POST['secret']:
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="Unknown project name and/or project secret"></red5missioncontrol>');
			return False

		return True

	def server(self):
		servers = memcache.get('servers')
		if len(servers) == 0: # Nothing in there, use backup/default data!
			return {
				'httpprefix': 'http://79.125.7.38:5080/simpleVideoRec/streams/',
				'rtmpprefix': 'rtmp://79.125.7.38/',
				'timestamp': int(time.time())
				}	
		return servers[int(random.random() * len(servers))]

class Record(PostRequest):
	def post(self):
		if self.authorized():
			recording = Recording()
			recording.project = self.request.POST['project']
			d = [random.choice(string.letters) for x in xrange(32)]
			recording.onetimecode = "".join(d)
			recording.put()
			stream = str(recording.created.strftime('%Y%m%d%H%M%S')) + '_' + str(recording.key()) + '_' + recording.onetimecode
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			server = self.server()
			self.response.out.write('<red5missioncontrol><record rmtp="' + server['rtmpprefix'] + 'simpleVideoRec" stream="' + stream + '" http="' + server['httpprefix'] + stream + '.flv" meta="' + server['httpprefix'] + stream + '.flv.meta" time_left="3600" /></red5missioncontrol>');

class RecordConsume(PostRequest):
	def post(self):
		if not self.request.POST.has_key('stream'):
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No stream HTTP POST variable given"></red5missioncontrol>');
			return

		try:
			parts = self.request.POST['stream'].split('_', 3)
			recording = Recording.get(parts[1])
		except:
			recording = None

		if recording == None:
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No such stream left for consuming"></red5missioncontrol>');
			return

		if parts[0] != str(recording.created.strftime('%Y%m%d%H%M%S')) or parts[2] != recording.onetimecode:
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No such stream left for consuming"></red5missioncontrol>');
			return

		recording.delete()
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<red5missioncontrol><consume /></red5missioncontrol>');

class ServerNotification(PostRequest):
	def post(self):
		if not self.request.POST.has_key('rtmpprefix'):
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No RTMP prefix sent."></red5missioncontrol>');
			return

		if not self.request.POST.has_key('httpprefix'):
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No HTTP prefix sent."></red5missioncontrol>');
			return

		q = taskqueue.Queue('servers')
		q.add(taskqueue.Task(
			params = {
				'httpprefix': self.request.POST['httpprefix'],
				'rtmpprefix': self.request.POST['rtmpprefix']
				}
			))

class ServersQueueWorker(webapp.RequestHandler):
	def post(self):
		if self.request.POST.has_key('cleanup'):
			timeout = int(self.request.POST['cleanup'])
			if timeout < 120:
				timeout = 120
			servers = memcache.get('servers')
			newservers = []
			if type(servers) is list:
				for server in servers:
					if (server['timestamp'] + timeout) >= int(time.time()):
						newservers.append(server)
			memcache.set('servers', newservers)

		if self.request.POST.has_key('httpprefix') and self.request.POST.has_key('rtmpprefix'):
			servers = memcache.get('servers')
			if type(servers) is not list:
				servers = []
			newservers = []
			for server in servers:
				if server['httpprefix'] != self.request.POST['httpprefix'] or server['rtmpprefix'] != self.request.POST['rtmpprefix']:
					newservers.append(server)
			newservers.append({
				'httpprefix': self.request.POST['httpprefix'],
				'rtmpprefix': self.request.POST['rtmpprefix'],
				'timestamp': int(time.time())
			})
			memcache.set('servers', newservers)

class Test(webapp.RequestHandler):
	def get(self):
		self.response.out.write(template.render('test.html', {
			'domain': os.environ['HTTP_HOST'],
			'servers': memcache.get('servers')
			}))

def main():
	run_wsgi_app(
		webapp.WSGIApplication([
			('/_ah/cron/everyminute', CronJobEveryMinute),
			('/_ah/queue/servers', ServersQueueWorker),
			('/crossdomain.xml', CrossDomainPolicy),
			('/record/*', Record),
			('/record/consume/*', RecordConsume),
			('/servernotification/*', ServerNotification),
			('/test/*', Test),
			('.*', Error)
		]
		, debug=True))

if __name__ == '__main__':
	main()

