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
		@newsCollection.find({ year: year }).sort({ date: -1}).limit(num).toArray (err, news) -> callback err, news if not err?
	
	# Competitions
	# upgrade competition object with helper functions from this class
	upgradeCompetition: (competition) ->
		if competition?
			competition.getState = () => @getCompetitionState(competition)
			competition.getEntries = (err, callback) => @getEntrants(competition)
		competition
	
	getDefaultYear: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find({}, { year: 1 }).sort({ year: -1 }).limit(1).toArray (err, competitions) -> callback err, competitions[0].year if not err?
	
	getDefaultCompetition: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find().sort({ year: -1 }).limit(1).toArray (err, competitions) => callback err, @upgradeCompetition(competitions[0]) if not err?
	
	getCompetition: (year, callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.findOne { year: year }, (err, competition) => callback err, @upgradeCompetition(competition) if not err?
	
	getCompetitionList: (callback) ->
		throw 'callback required' if not callback?
		@competitionsCollection.find({}, { year: 1 }).sort({ year: -1 }).map((year) -> year.year).toArray (err, years) -> callback err, years if not err?
	
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
	
	# Entrants
	getCompetitionEntries: (competition, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.find({ competition: competition.year }).toArray (err, entries) -> callback err, entries if not err?
	
	
	# Users
	# upgrade user object with helper functions from this class
	upgradeUser: (user) ->
		if user?
			user.getCompetitionEntries = (err, callback) => @getUserCompetitionEntries user, err, callback
		user
	
	getUserData: (id, callback) ->
		throw 'callback required' if not callback?
		@usersCollection.findOne { id: id }, (err, user) -> callback err, user if not err?
	
	updateUserData: (user) ->
		#db.collection('users').update { id: user.id }, user, true, false
		@usersCollection.update { id: user.id }, { $set: user }, true, false
	
	getUserCompetitionEntries: (user, err, callback) ->
		throw 'callback required' if not callback?
		@entrantsCollection.find({ user: user.id }).toArray (err, entries) -> callback err, entries if not err?