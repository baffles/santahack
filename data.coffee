module.exports = class Data
	@competitionStates:
		Upcoming: { seq: 1, jsonDisplay: 'upcoming' }
		Registration: { seq: 2, jsonDisplay: 'registration' }
		Voting: { seq: 3, jsonDisplay: 'voting' }
		VotingIntermission: { seq: 4, jsonDisplay: 'intermission' }
		Development: { seq: 5, jsonDisplay: 'development' }
		DevelopmentGrace: { seq: 6, jsonDisplay: 'development' }
		DevelopmentIntermission: { seq: 7, jsonDisplay: 'intermission' }
		ReleasePrivate: { seq: 8, jsonDisplay: 'release-gifts' }
		ReleasePublic: { seq: 9, jsonDisplay: 'release-public' }
	
	@defaultOptions:
		usersCollectionName: 'users'
		newsCollectionName: 'news'
		competitionCollectionName: 'competitions'
		entriesCollectionName: 'entries'
	
	constructor: (@db, @options = {}) ->
		@usersCollection = @db.collection(@getOption 'usersCollectionName')
		@newsCollection = @db.collection(@getOption 'newsCollectionName')
		@competitionsCollection = @db.collection(@getOption 'competitionCollectionName')
		@entriesCollection = @db.collection(@getOption 'entriesCollectionName')
	
	getOption: (option) -> @options[option] ? Data.defaultOptions[option]
	
	# News
	getNews: (year, num, callback) ->
		throw 'callback required' if not callback?
		@newsCollection.find({ year: year }).sort({ date: -1}).limit(num).toArray (err, news) -> callback err, news
	
	saveNews: (post) ->
		if post._id?
			# clean up the news object
			id = post._id
			delete post._id # since we can't update including the _id object
			@newsCollection.update { _id: id }, { $set: post }
		else
			@newsCollection.save post
	
	deleteNews: (post) ->
		# remove a news entry
		if post._id?
			@newsCollection.remove { _id: new lib.mongolian.ObjectId(post._id) }
	
	# Competitions
	# upgrade competition object with helper functions from this class
	upgradeCompetition: (competition) ->
		if competition?
			competition.getState = () => @getCompetitionState(competition)
			competition.getEntries = (callback) => @getEntrants(competition)
		competition
	
	getDefaultYear: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find({}, { year: 1 }).sort({ year: -1 }).limit(1).toArray (err, competitions) -> callback err, competitions[0].year
	
	getDefaultCompetition: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find().sort({ year: -1 }).limit(1).toArray (err, competitions) => callback err, @upgradeCompetition competitions[0]
	
	getCompetition: (year, callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.findOne { year: year }, (err, competition) => callback err, @upgradeCompetition competition
	
	getCompetitionList: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find({}, { year: 1 }).sort({ year: -1 }).map((year) -> year.year).toArray (err, years) -> callback err, years
	
	saveCompetition: (competition) ->
		if competition.year?
			@competitionsCollection.update { year: competition.year }, { $set: competition }, true, false
	
	getCompetitionState: (competition) ->
		now = new Date
		if now < competition.registrationBegin
			return Data.competitionStates.Upcoming
		else if now < competition.registrationEnd
			return Data.competitionStates.Registration
		else if competition.votingBegin <= now < competition.votingEnd
			return Data.competitionStates.Voting
		else if now < competition.devBegin
			return Data.competitionStates.VotingIntermission
		else if now < competition.devEnd
			return Data.competitionStates.Development
		else if now < competition.entryCutoff
			return Data.competitionStates.DevelopmentGrace
		else if now < competition.privateRelease
			return Data.competitionStates.DevelopmentIntermission
		else if now < competition.publicRelease
			return Data.competitionStates.ReleasePrivate
		else if now >= competition.publicRelease
			return Data.competitionStates.ReleasePublic
		else # sanity check
			throw "unknown competition state"
	
	# Entries
	upgradeEntry: (entry) ->
		if entry?
			entry.isWishlistComplete = () ->
				entry.wishlist? and
				entry.wishlist.wishes?.length == 3 and entry.wishlist.each (wish) -> wish.length > 0 and
				entry.wishlist.machinePerformance?.length > 0 and entry.wishlist.preferredOS?.length > 0 and
				entry.wishlist.canDev?.length > 0
		entry
	
	getCompetitionEntries: (competition, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.find({ year: competition.year }).toArray (err, entries) => callback err, entries.map (entry) => @upgradeEntry entry
	
	getUserCompetitionEntry: (user, competition, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.findOne { user: user.id, year: competition.year }, (err, entry) => callback err, @upgradeEntry entry
	
	getUserCompetitionEntries: (user, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.find({ user: user.id }).toArray (err, entries) => callback err, entries.map (entry) => @upgradeEntry entry
	
	saveCompetitionEntry: (entry) ->
		if entry.user? and entry.year?
			@entriesCollection.update { user: entry.user, year: entry.year }, { $set: entry }, true, false
	
	removeCompetitionEntry: (entry) ->
		if entry.user? and entry.year?
			@entriesCollection.remove { user: entry.user, year: entry.year }
	
	# Users
	# upgrade user object with helper functions from this class
	upgradeUser: (user) ->
		if user?
			user.getCompetitionEntry = (competition, callback) => @getUserCompetitionEntry user, competition, callback
			user.getCompetitionEntries = (competition, callback) => @getUserCompetitionEntries user, callback
		user
	
	getUserData: (id, callback) ->
		throw 'callback required' if not callback?
		@usersCollection.findOne { id: id }, (err, user) -> callback err, user
	
	updateUserData: (user) ->
		@usersCollection.update { id: user.id }, { $set: user }, true, false