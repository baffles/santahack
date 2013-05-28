# Main entry point for all router routes

module.exports =
	register: (app, data) ->
		(require './home').register app, data
		(require './user').register app, data