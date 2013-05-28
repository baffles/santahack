# Helpers; mainly used in the templates

lib = 
	marked: require 'marked'
	moment: require 'moment'

module.exports =
	register: (app) ->
		lib.marked.setOptions
			gfm: true
			pedantic: false
			sanitize: true
		app.locals.markdown = lib.marked

		app.locals.friendlyDate = (date) -> lib.moment(date).fromNow()
		app.locals.displayDate = (date) -> lib.moment(date).utc().calendar()
		app.locals.utcDate = (date) -> lib.moment(date).utc().format 'dddd, MMMM Do YYYY, h:mm:ss a [UTC]'
		app.locals.getDisplayTime = () -> lib.moment().utc().format 'MMM D[,] YYYY, h:mm A [UTC]'
		app.locals.getGenerationTime = (requestTime) -> lib.moment().diff(lib.moment(requestTime), 'seconds', true)

		s3Content = process.env.AWS_CONTENT
		app.locals.getS3Url = (filename) => "http://#{s3Content}/#{filename}"

		app.locals.displayBytes = (bytes) ->
			units = [ 'B', 'KB', 'MB' ]
			unit = 0
			val = bytes
			while val > 1024
				unit++
				val /= 1024
			"#{Math.round(val * 100) / 100} #{units[unit]}"