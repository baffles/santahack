# Main entry point for all middleware

lib = 
	express: require 'express'

module.exports =
	register: (app, data) ->
		app.use (req, res, next) ->
			# record request time immediately, for later use
			res.locals.requestTime = new Date()
			next()

		app.use lib.express.favicon "#{__dirname}/../public/images/favicon.ico"

		(require './assets').register app
		(require './session').register app

		app.use lib.express.bodyParser()
		app.use lib.express.methodOverride()

		(require './year').register app, data
		(require './template-data').register app, data

		# no caching for dynamic pages
		app.use (req, res, next) ->
			res.setHeader "Cache-Control", "no-cache"
			next()

		# use router for anything that makes it here (non-dynamic)
		app.use app.router

		# default route provides 404 error page
		app.use (req, res, next) ->
			res.status 404
			res.render 'error-404'

		(require './error-handling').register app