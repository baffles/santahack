_ = require('underscore')._
seq = require('seq')

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
	getAllNews: (year, callback) ->
		throw 'callback required' if not callback?
		@newsCollection.find({ year: year }).sort({ date: -1}).toArray callback
	
	getNews: (year, num, offset, callback) ->
		throw 'callback required' if not callback?
		@newsCollection.find({ year: year, date: { $lte: new Date() } }, { _id: 0 }).sort({ date: -1}).skip(offset).limit(num).toArray callback
	
	getNewsCount: (year, callback) ->
		throw 'callback required' if not callback?
		@newsCollection.find({ year: year, date: { $lte: new Date() } }).count callback
	
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
			competition.getState = () => @getCompetitionState competition 
			competition.getEntries = (callback) => @getCompetitionEntries competition, callback
			competition.getParticipantInfo = (callback) => @getParticipantInfo competition, callback
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
		@competitionsCollection.find({}, { year: 1 }).sort({ year: -1 }).map((year) -> year.year).toArray callback
	
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
	###
		user:
		year:
		wishlist:
		hasVoted:
		isEligible:
		votesCast:
		assignment:
		blogEntries:
		submission:
	###
	upgradeEntry: (entry) ->
		if entry?
			entry.checkWishlist = () ->
				entry.wishlist? and
				entry.wishlist.wishes?.length is 3 and _(entry.wishlist.wishes).all((wish) -> wish.length > 0) and
				entry.wishlist.machinePerformance?.length > 0 and entry.wishlist.preferredOS?.length > 0 and
				entry.wishlist.canDev?.length > 0
			
			entry.clean = () => @downgradeEntry entry
			entry.isWishlistComplete = () -> entry.wishlist?.isComplete
			entry.getVoteItems = (callback) => @getVoteItems entry, callback
			entry.saveVotes = (votes) => @saveVotes entry, votes
			
			entry.getAssignment = (callback) =>
				if entry.assignment?
					seq()
						.par_((s) => @getUserWishlist entry.assignment, entry.year, s.into 'wishlist')
						.par_((s) => @getUserData entry.assignment, s.into 'user')
						.catch((err) -> callback err, null)
						.seq(() -> callback null, @vars)
			
			Data.upgradeWishlist entry.wishlist
		entry
	
	@upgradeWishlist: (wishlist) ->
		if wishlist?
			wishlist.getMachinePerformanceDisplay = () ->
				switch wishlist.machinePerformance
					when 'lowend' then 'low end'
					when 'midrange' then 'mid-range'
					when 'highend' then 'high end'
					else 'unknown'
		
			wishlist.getPreferredOSDisplay = () ->
				switch wishlist.preferredOS
					when 'windows' then 'Windows&reg;'
					when 'osx' then 'OS X&reg;'
					when 'linux' then 'Linux'
					else 'unknown'
		
			wishlist.getDevListDisplay = () ->
				oses = for os in wishlist.canDev
					switch os
						when 'windows' then 'Windows&reg;'
						when 'osx' then 'OS X&reg;'
						when 'mac' then 'OS X&reg;'
						when 'linux' then 'Linux'
						else 'unknown'
				oses.join ', '
		
		wishlist
	
	downgradeEntry: (entry) ->
		if entry?
			delete entry._id
			delete entry.clean
			delete entry.checkWishlist
			delete entry.isWishlistComplete
			delete entry.getVoteItems
			delete entry.saveVotes
			delete entry.getAssignment
			
			if entry.wishlist?
				delete entry.wishlist.getMachinePerformanceDisplay
				delete entry.wishlist.getPreferredOSDisplay
				delete entry.wishlist.getDevListDisplay
	
	getCompetitionEntries: (competition, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.find({ year: competition.year }).toArray (err, entries) => callback err, entries.map (entry) => @upgradeEntry entry
	
	getParticipantInfo: (competition, callback) ->
		throw 'callback required' if not callback?
		seq()
			.par_((s) => @entriesCollection.find({ year: competition.year }).count s.into 'participants')
			.par_((s) => @entriesCollection.find({ year: competition.year, 'wishlist.isComplete': true }).count s.into 'completeWishlists')
			.par_((s) => @entriesCollection.find({ year: competition.year, 'wishlist.isComplete': true, 'hasVoted': true }).count s.into 'hasVoted')
			.par_((s) => @entriesCollection.find({ year: competition.year, isEligible: true }).count s.into 'eligibleParticipants')
			.catch((err) -> callback err, null)
			.seq_((s) -> callback null, s.vars)
	
	getUserCompetitionEntry: (user, competition, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.findOne { user: user.id, year: competition.year }, (err, entry) => callback err, @upgradeEntry entry
	
	getUserCompetitionEntries: (user, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.find({ user: user.id }).toArray (err, entries) => callback err, entries.map (entry) => @upgradeEntry entry
	
	getUserWishlist: (userid, year, callback) ->
		throw 'callback required' if not callback?
		@entriesCollection.findOne { user: userid, year }, (err, entry) -> callback err, Data.upgradeWishlist entry?.wishlist
	
	saveCompetitionEntry: (entry) ->
		# clean up entry
		if entry.clean?
			entry.clean()
		
		if entry.user? and entry.year?
			@entriesCollection.update { user: entry.user, year: entry.year }, { $set: entry }, true, false
	
	removeCompetitionEntry: (entry) ->
		if entry.user? and entry.year?
			@entriesCollection.remove { user: entry.user, year: entry.year }
	
	getWishes: (year, callback) ->
		seq()
			.seq_((s) => @entriesCollection.find({ year: year }, { user: 1, 'wishlist.wishes': 1, 'wishlist.isComplete': 1 }).toArray s)
			.flatten()
			# -- filter out nulls from the seqMap below
			.seqMap((entry) -> this null, entry?.wishlist?.wishes?.map (wish, idx) -> { destUser: entry.user, wish: idx, wishText: wish, isListComplete: entry.wishlist.isComplete })
			.flatten()
			.unflatten()
			.seq((wishes) -> callback null, _.filter wishes, (wish) -> wish?)
	
	saveWishes: (year, wishes) ->
		# piggy backing off the vote system, we're getting [ { destUser:, wish:, wishText: } ]
		for wish in wishes
			$set = {}
			$set["wishlist.wishes.#{wish.wish}"] = wish.wishText
			@entriesCollection.update { user: wish.destUser, year: year }, { $set }
	
	getVoteItems: (entry, callback) ->
		# get votes: [ { destUser:, wish:, score? } ]
		seq()
			.seq_((s) => @entriesCollection.find({ user: { $ne: entry.user }, year: entry.year, 'wishlist.isComplete': true }, { user: 1, 'wishlist.wishes': 1 }).toArray s)
			.flatten()
			.parMap((entry) -> this null, entry?.wishlist?.wishes?.map (wish, idx) -> { destUser: entry.user, wish: idx, wishText: wish, score: null })
			.flatten()
			.unflatten()
			.seq((wishes) ->
				if entry.votesCast? then wishes = wishes.concat entry.votesCast
				wishes = _.groupBy(wishes, (wish) -> "destUser: '#{wish.destUser}', wish: '#{wish.wish}'")
				voteList = []
				for group, wish of wishes
					voteList.push _.reduce wish, (o, i) ->
						return i if not o?
						o.score = i.score if not o.score? and i.score?
						o.wishText = i.wishText if not o.wishText? and i.wishText?
						o
				
				callback null, voteList
			).catch((err) -> callback err, null)
	
	saveVotes: (entry, votes) ->
		# send in votes: [ { destUser: 'xxxx', wish: 'wishx', score: x } ]
		
		# compare current votes from entry with new votes
		newVotes = []
		changedVotes = []
		
		for newVote in votes
			oldVote = _.find(entry.votesCast, (ov) -> ov.destUser is newVote.destUser and ov.wish is newVote.wish)
			if oldVote? and oldVote.score isnt newVote.score
				changedVotes.push { oldVote, newVote }
			else if not oldVote?
				newVotes.push newVote
		
		for vote in newVotes
			# for new votes, just push them into the vote record and update the destination wishlist score and count
			@entriesCollection.update { user: entry.user, year: entry.year }, { $push: { votesCast: vote } }
			$inc = {}
			$inc["wishlist.votes.#{vote.wish}.count"] = 1
			$inc["wishlist.votes.#{vote.wish}.score"] = vote.score
			@entriesCollection.update { user: vote.destUser, year: entry.year }, { $inc }
		
		for change in changedVotes
			# for changed votes, we have to update the existing vote record and update the destination wishlist score
			@entriesCollection.update { user: entry.user, year: entry.year, votesCast: change.oldVote }, { $set: { 'votesCast.$': change.newVote } }
			$inc = {}
			$inc["wishlist.votes.#{change.newVote.wish}.score"] = change.newVote.score - change.oldVote.score
			@entriesCollection.update { user: change.newVote.destUser, year: entry.year }, { $inc }
		
		# update hasVoted, must vote on at least half of the wishes
		if not entry.hasVoted
			numVotes = entry.votesCast?.length + newVotes.length
			@entriesCollection.find({ user: { $ne: entry.user }, 'wishlist.isComplete': true }).count (err, count) =>
				throw err if err?
				if numVotes > count * 1.5 # count * 3 / 2
					@entriesCollection.update { user: entry.user }, { $set: { hasVoted: true } }
	
	getEligibility: (year, callback) ->
		seq()
			.seq_((s) => @entriesCollection.find({ year: year }, { user: 1, isEligible: 1 }).toArray s)
			.flatten()
			.parMap_((s, entry) => @getUserData entry.user, (err, user) -> s err, { name: user.name, isEligible: entry.isEligible ? false })
			.unflatten()
			.seq((elig) -> callback null, elig)
			.catch((err) -> callback err, null)
	
	clearEligibility: (year) ->
		@entriesCollection.update { year: year }, { $unset: { isEligible: '' } }, false, true

	updateEligibility: (year) ->
		@entriesCollection.update { year: 2012, 'wishlist.isComplete': true, hasVoted: true, 'wishlist.votes': { $exists: true }, $where: () ->
				for i, vote of @wishlist.votes
					if Math.round(10 * vote.score / vote.count) >= 25
						return true
				return false
			}, { $set: { isEligible: true } }, false, true
	
	getEligibleWishVotes: (year, callback) ->
		seq()
			.seq_((s) => @entriesCollection.find({ year: year, isEligible: true }, { user: 1, 'votesCast': 1 }).toArray s)
			.forEach((entries) -> @into('eligible') null, entries.map (entry) -> entry.user)
			.flatten()
			.seqMap((entry) -> this null, entry.votesCast.map (vote, idx) => { sourceUser: entry.user, destUser: vote.destUser, score: vote.score, isEligible: @vars.eligible.indexOf(vote.destUser) >= 0 })
			.flatten()
			.parFilter((vote, i) -> @into(i) null, if vote.isEligible then vote else null)
			.unflatten()
			.seq((votes) -> callback null, votes)
			.catch((err) -> callback err, null)
	
	savePairings: (year, pairings) ->
		for pairing in pairings
			@entriesCollection.update({ year: year, user: pairing.sourceUser}, { $set: { assignment: pairing.destUser } })
	
	# Users
	# upgrade user object with helper functions from this class
	upgradeUser: (user) ->
		if user?
			user.getCompetitionEntry = (competition, callback) => @getUserCompetitionEntry user, competition, callback
			user.getCompetitionEntries = (competition, callback) => @getUserCompetitionEntries user, callback
		user
	
	getUserData: (id, callback) ->
		throw 'callback required' if not callback?
		@usersCollection.findOne { id: id }, callback
	
	updateUserData: (user) ->
		@usersCollection.update { id: user.id }, { $set: user }, true, false