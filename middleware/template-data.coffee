# Provides loads of data used by view templates

lib = 
	express: require 'express'
	seq: require 'seq'
	data: require '../lib/data'

module.exports = (app, data) ->
	# make user, session data and return URL available to templates
	app.use (req, res, next) ->
		res.locals.session = req.session
		res.locals.returnURL = req.path
		req.user = data.upgradeUser req.session?.user
		next()

	# query for and make competition data available to templates
	app.use (req, res, next) ->
		if req.year?
			lib.seq()
				.seq(() -> data.getCompetition req.year, this)
				.seq((competition) ->
					if competition?
						req.competition = res.locals.competition = competition
						res.locals.competitionStates = lib.data.competitionStates
						next()
					else
						res.status 404
						res.render 'error-404'
				).catch((err) -> next err)
		else
			next()

	# make current entry info available for logged in users
	app.use (req, res, next) ->
		if req.year? and req.user?
			lib.seq()
				.seq(() -> req.user.getCompetitionEntry req.competition, this)
				.seq((entry) ->
					req.competitionEntry = res.locals.competitionEntry = entry
					next()
				).catch((err) -> next err)
		else
			next()

	# set warning messages for the user
	app.use (req, res, next) ->
		compState = req.competition?.getState()
		if compState is lib.data.competitionStates.Registration and req.competitionEntry? and not req.competitionEntry.isWishlistComplete()
			res.locals.warnMsg = 'It looks like your wishlist is incomplete. Please complete it in time to ensure you are allowed to participate!'
			res.locals.showWarnMsg = true
		else if compState is lib.data.competitionStates.Voting and req.competitionEntry?.isWishlistComplete() and not req.competitionEntry.hasVoted
			res.locals.warnMsg = 'It looks like you haven\'t voted on at least half of the game ideas yet. Please submit your votes in time to ensure you remain eligible!'
			res.locals.showWarnMsg = true
		else if compState is lib.data.competitionStates.Development and req.competitionEntry?.isSubmissionPartiallyComplete()
			res.locals.warnMsg = 'It looks like you haven\'t finished your submission. Please make sure to finish filling in all required information on the submission page before the end of the competition!'
			res.locals.showWarnMsg = true
		else if compState is lib.data.competitionStates.DevelopmentGrace and req.competitionEntry?.isEligible
			res.locals.warnMsg = 'The competition is now over. There is a short grace period if you still need to edit or upload your entry.'
			res.locals.showWarnMsg = true
		next()