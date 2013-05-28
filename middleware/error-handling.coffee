# Provides error handling, depending on environment

lib = 
	express: require 'express'

module.exports =
	register: (app) ->
		if app.settings.env is 'development'
			app.use lib.express.errorHandler
				dumpExceptions: true
				showStack: true
		else
			app.use (err, req, res, next) ->
				console.log "[Server error]: #{err}"
				res.status 500
				res.render 'error-500'
			app.use (err, req, res, next) ->
				res.send 500, 'Uh oh... internal server error while processing another internal server error.'