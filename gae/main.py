from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp import template
from google.appengine.ext.webapp.util import run_wsgi_app
import os
import random
import string

class Project(db.Model):
	name = db.StringProperty()
	secret = db.StringProperty()

class Recording(db.Model):
	project = db.StringProperty()
	onetimecode = db.StringProperty()
	created = db.DateTimeProperty(auto_now_add = True)

class CrossDomainPolicy(webapp.RequestHandler):
	def get(self):
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<cross-domain-policy><allow-access-from domain="*" /></cross-domain-policy>');

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
			project.name = self.request.POST['project']
			project.secret = ''
			project.put()

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

class Record(PostRequest):
	def post(self):
		if self.authorized():
			recording = Recording()
			recording.project = self.request.POST['project']
			d = [random.choice(string.letters) for x in xrange(32)]
			recording.onetimecode = "".join(d)
			recording.put()
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol><record url="rtmp://88.80.16.137/simpleVideoRec" stream="' + str(recording.created.strftime('%Y%m%d%H%M%S')) + '_' + str(recording.key()) + '_' + recording.onetimecode + '" /></red5missioncontrol>');

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
			self.response.out.write('<red5missioncontrol error="No such stream left for consuming."></red5missioncontrol>');
			return

		if parts[0] != str(recording.created.strftime('%Y%m%d%H%M%S')) or parts[2] != recording.onetimecode:
			self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
			self.response.out.write('<?xml version="1.0"?>\r\n');
			self.response.out.write('<red5missioncontrol error="No such stream left for consuming."></red5missioncontrol>');
			return

		recording.delete()
		self.response.headers['Content-Type'] = "text/xml; charset=utf-8"
		self.response.out.write('<?xml version="1.0"?>\r\n');
		self.response.out.write('<red5missioncontrol><consume /></red5missioncontrol>');

class Test(webapp.RequestHandler):
	def get(self):
		self.response.out.write(template.render('test.html', {
			'domain': os.environ['HTTP_HOST']
			}))

def main():
	run_wsgi_app(
		webapp.WSGIApplication([
			('/crossdomainpolicy.xml', CrossDomainPolicy),
			('/record/*', Record),
			('/record/consume/*', RecordConsume),
			('/test/*', Test),
			('.*', Error)
		]
		, debug=True))

if __name__ == '__main__':
	main()

