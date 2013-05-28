lib =
	seq: require 'seq'

module.exports = (app, data) ->
	# add year to request object, if there is one. add a year redirect convenience function for pages that need a year
	app.use (req, res, next) ->
		yearMatch = req.path.match(/^\/(\d{4})\//)
		req.year = res.locals.year = parseInt(yearMatch[1]) if yearMatch?
		res.locals.genLink = (path) -> "/#{req.year}#{path}"
		req.needsYearRedirect = () ->
			if not req.year?
				lib.seq()
					.seq(() -> data.getDefaultYear this)
					.seq((defaultYear) ->
						res.redirect "/#{defaultYear}#{req.path}"
					).catch((err) -> next err)
				return true
			else
				return false
		next()