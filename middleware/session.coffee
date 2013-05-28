# Basic session management

lib = 
	express: require 'express'
	mongoStore: require 'connect-mongo'

module.exports =
	register: (app) ->
		# need cookieParser for session
		app.use lib.express.cookieParser()

		# use sessions, stored in mongo
		app.use lib.express.session
			store: new (lib.mongoStore lib.express)
				url: process.env.MONGOHQ_URL
				db: 'test'
				clear_interval: 3600 # clear expired sessions hourly
			key: 'session'
			cookie:
				maxAge: 24 * 60 * 60 * 1000 # sessions expire in a day
			secret: 'santa shack'