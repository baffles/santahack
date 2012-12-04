lib = 
	express: require 'express'
	compiler: require 'connect-compiler'
	marked: require 'marked'
	mongolian: require 'mongolian'
	mongoStore: require 'connect-mongo'
	moment: require 'moment'
	underscore: require 'underscore'
	seq: require 'seq'
	accSso: require './acc-sso'
	data: require './data'
	voteID: require './vote-id'

_ = lib.underscore._

db = if process.env.MONGOHQ_URL? then new lib.mongolian process.env.MONGOHQ_URL else new lib.mongolian().db 'test'

accSso = new lib.accSso
data = new lib.data db
voteID = new lib.voteID 'aes256', 'santas shack hack'

app = lib.express()

app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'

app.use lib.express.favicon "#{__dirname}/public/images/favicon.ico"

app.use lib.compiler
	enabled: [ 'coffee', 'stylus', 'uglify', 'jade' ]
	src: 'assets'
	dest: 'assets/compiled'
	mount: '/static'
	options:
		stylus: { compress: true }
		jade: { pretty: false }
app.use lib.compiler
	enabled: [ 'uglify' ]
	src: [ 'assets', 'assets/compiled' ]
	dest: 'assets/compiled'
	mount: '/static'
app.use '/static', lib.express.static "#{__dirname}/public"
app.use '/static', lib.express.static "#{__dirname}/assets/compiled"

app.use lib.express.cookieParser()

app.use lib.express.session
	store: new (lib.mongoStore lib.express)
		url: process.env.MONGOHQ_URL
		db: 'test'
	secret: 'santa shack'
app.use lib.express.bodyParser()
app.use lib.express.methodOverride()

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
				req.competition = res.locals.competition = competition
				res.locals.competitionStates = lib.data.competitionStates
				next()
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
	if req.competition?.getState() is lib.data.competitionStates.Registration and req.competitionEntry? and not req.competitionEntry.isWishlistComplete()
		res.locals.warnMsg = 'It looks like your wishlist is incomplete. Please complete it in time to ensure you are allowed to participate!'
		res.locals.showWarnMsg = true
	else if req.competition?.getState() is lib.data.competitionStates.Voting and req.competitionEntry?.isWishlistComplete() and not req.competitionEntry.hasVoted
		res.locals.warnMsg = 'It looks like you haven\'t voted on at least half of the descriptions yet. Please submit your votes in time to ensure you are eligible!'
		res.locals.showWarnMsg = true
	next()

app.use app.router

if app.settings.env = 'development'
	app.use lib.express.errorHandler
		dumpExceptions: true
		showStack: true
else
	app.use lib.express.errorHandler 

lib.marked.setOptions
	gfm: true
	pedantic: false
	sanitize: true
app.locals.markdown = lib.marked

app.locals.friendlyDate = (date) -> lib.moment(date).fromNow()
app.locals.utcDate = (date) -> lib.moment(date).utc().format 'dddd, MMMM Do YYYY, h:mm:ss a [UTC]'
app.locals.displayTime = () -> lib.moment().utc().format 'MMM D[,] YYYY, h:mm A [UTC]'

# /
app.get /^\/(\d{4})?\/?$/, (req, res) ->
	if req.params[0]?
		res.redirect "/#{req.params[0]}/home"
	else
		res.redirect '/home'

app.get '/login', (req, res) ->
	returnUrl = req.query.return
	accReturn = process.env.ACCRETURN ? "http://#{req.host}/login-return"
	accReturn += "$return=#{returnUrl}" if returnUrl?
	res.redirect accSso.getLoginUrl accReturn

app.get '/logout', (req, res) ->
	req.session.user = null
	res.redirect (req.query.return) ? '/'

app.get '/login-return', (req, res, next) ->
	req.session.user = null

	accSso.processAuthenticationToken (req.query.token), (accErr, accUser) ->
		if accErr?
			next(accErr)
		else
			data.updateUserData accUser
			data.getUserData accUser.id, (err, user) ->
				if err?
					next(err)
				else
					delete user._id # no need to store the db ID in the session
					req.session.user = user
					res.redirect (req.query.return) ? '/'

app.get '/admin', (req, res) ->
	if not req.session?.user?.isAdmin
		res.send 401, 'Unauthorized.'
		return
	
	res.render 'admin',
		title: 'SantaHack Admin'

app.get '/info.json', (req, res) ->
	data.getDefaultCompetition (err, competition) ->
		now = new Date().valueOf()
		res.json
			year: competition.year
			participants: 0
			currentPhase: competition.getState().jsonDisplay
			timeLeft:
					'registration-begin': (competition.registrationBegin.valueOf() - now) / 1000 | 0
					'registration-end': (competition.registrationEnd.valueOf() - now) / 1000 | 0
					'voting-begin': (competition.votingBegin.valueOf() - now) / 1000 | 0
					'voting-end': (competition.votingEnd.valueOf() - now) / 1000 | 0
					'development-begin': (competition.devBegin.valueOf() - now) / 1000 | 0
					'development-end': (competition.devEnd.valueOf() - now) / 1000 | 0
					'release-gifts': (competition.privateRelease.valueOf() - now) / 1000 | 0
					'release-public': (competition.publicRelease.valueOf() - now) / 1000 | 0

# /home
app.get /^\/(?:\d{4}\/)?home$/, (req, res, next) ->
	if not req.needsYearRedirect()
		data.getNews req.year, 5, (err, news) ->
			if err?
				next err
			else
				res.render 'home',
					title: 'SantaHack'
					posts: news

app.get /^\/(?:\d{4}\/)?years$/, (req, res) ->
	if not req.needsYearRedirect()
		#data.getCompetition req.year, (err, competition) ->
			res.send req.competition.getState()
	#	competitionHelper.getCompetitionList (err, years) ->
			#res.send JSON.stringify years

# /rules
app.get /^\/(?:\d{4}\/)?rules$/, (req, res) ->
	if not req.needsYearRedirect()
		res.render 'rules',
			title: 'SantaHack'

# /participants
app.get /^\/(?:\d{4}\/)?participants$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> data.getCompetitionEntries req.competition, this)
			.flatten()
			.parMap((entry) -> data.getUserData entry.user, this)
			.unflatten()
			.seq((participants) ->
				res.render 'participants',
					title: 'SantaHack'
					participants: participants
			)

# /entry
app.post /^\/(?:\d{4}\/)?entry$/, (req, res) ->
	if not req.needsYearRedirect()
		if req.body.join?
			# join
			data.saveCompetitionEntry
				user: req.user.id
				year: req.year
			res.redirect res.locals.genLink '/wishlist'
		else if req.body.withdrawConfirm?
			data.removeCompetitionEntry req.competitionEntry
			res.redirect res.locals.genLink '/'
		else if req.body.cancel?
			res.redirect res.locals.genLink '/wishlist'

# /withdraw
app.get /^\/(?:\d{4}\/)?withdraw$/, (req, res) ->
	if not req.needsYearRedirect()
		res.render 'withdraw',
			title: 'SantaHack'

# /wishlist
app.get /^\/(?:\d{4}\/)?wishlist$/, (req, res) ->
	if not req.needsYearRedirect()
		entry = req.competitionEntry
		res.render 'wishlist',
			title: 'SantaHack',
			formVals: getWishlistFormVals req.competitionEntry
			showWarnMsg: req.competition.getState() isnt lib.data.competitionStates.Registration

app.get /^\/(?:\d{4}\/)?wishlist.json$/, (req, res) ->
	if not req.needsYearRedirect()
		res.send getWishlistFormVals req.competitionEntry

getWishlistFormVals = (entry) ->
	{
		wish1: entry?.wishlist?.wishes[0]
		wish2: entry?.wishlist?.wishes[1]
		wish3: entry?.wishlist?.wishes[2]
		machinePerformance: entry?.wishlist?.machinePerformance
		preferredOS: entry?.wishlist?.preferredOS
		canDevWindows: (entry?.wishlist?.canDev?.indexOf('windows') ? -1) >= 0
		canDevLinux: (entry?.wishlist?.canDev?.indexOf('linux') ? -1) >= 0
		canDevMac: (entry?.wishlist?.canDev?.indexOf('mac') ? -1) >= 0
	}

app.post /^\/(?:\d{4}\/)?wishlist$/, (req, res) ->
	if not req.needsYearRedirect()
		if req.competition.getState() is lib.data.competitionStates.Registration
			entry = req.competitionEntry
			entry.wishlist = 
				wishes: [ req.body.wish1, req.body.wish2, req.body.wish3 ]
				machinePerformance: req.body.machinePerformance
				preferredOS: req.body.preferredOS
				canDev: [ ]
			entry.wishlist.canDev.push 'windows' if req.body.canDevWindows?
			entry.wishlist.canDev.push 'linux' if req.body.canDevLinux?
			entry.wishlist.canDev.push 'mac' if req.body.canDevMac?
			
			entry.wishlist.isComplete = entry.checkWishlist()
		
			data.saveCompetitionEntry entry
		
			if req.body.json?
				res.json { success: true }
			else
				res.redirect res.locals.genLink '/wishlist'
		else
			if req.body.json?
				res.json { success: false, error: 'Competition not in registration.' }
			else
				res.redirect res.locals.genLink '/wishlist'

# /vote
app.get /^\/(?:\d{4}\/)?vote$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq_((seq) -> (req.competitionEntry?.getVoteItems seq) or seq())
			.seq((voteItems) ->
				voteItems = voteItems?.map (item) -> { id: voteID.toID(item), wishText: item.wishText, score: item.score }
				
				res.render 'vote',
					title: 'SantaHack'
					voteItems: _.shuffle voteItems
					showWarnMsg: req.competition.getState() isnt lib.data.competitionStates.Voting
			).catch((err) -> next err)

app.post /^\/(?:\d{4}\/)?vote$/, (req, res) ->
	if not req.needsYearRedirect()
		if req.competition.getState() is lib.data.competitionStates.Voting
			votes = []
			
			for id, score of req.body
				item = voteID.fromID(id)
				if item?.destUser? and item?.wish?
					vote = { destUser: item.destUser, wish: item.wish, score: parseInt(score) }
					if 0 < vote.score <= 5
						votes.push vote
			
			data.saveVotes req.competitionEntry, votes

			if req.query.json?
				res.json { success: true }
			else
				res.redirect res.locals.genLink '/vote'
		else
			if req.query.json?
				res.json { success: false, error: 'Competition not in voting.' }
			else
				res.redirect res.locals.genLink '/vote'

# /task
#todo later

# /submit
#todo later

# /gift
#todo now [for 2011]

# /downloads
#todo now [for 2011]

#! add logging facility

# admin functions
# should do better w/ check errors from DB on updates/saves
app.get '/admin/getCompetitionList', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	data.getCompetitionList (err, years) ->
		if err?
			res.json 500, err
		else
			res.json years

app.get '/admin/getCompetition', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	data.getCompetition parseInt(req.query.year), (err, comp) ->
		if err?
			res.json 500, err
		else
			if comp?
				delete comp._id # we don't want to send this crap
				res.json comp
			else
				res.json null

app.post '/admin/saveCompetition', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	competition =
		year: parseInt req.body.year
		registrationBegin: new Date req.body.registrationBegin
		registrationEnd: new Date req.body.registrationEnd
		votingBegin: new Date req.body.votingBegin
		votingEnd: new Date req.body.votingEnd
		devBegin: new Date req.body.devBegin
		devEnd: new Date req.body.devEnd
		entryCutoff: new Date req.body.entryCutoff
		privateRelease: new Date req.body.privateRelease
		publicRelease: new Date req.body.publicRelease
		rules: req.body.rules
	
	data.saveCompetition competition
	res.json { success: true }

app.get '/admin/getNews', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	data.getNews parseInt(req.query.year), 0, (err, news) ->
		if err?
			res.json 500, err
		else
			newsItem._id = newsItem._id.toString() for newsItem in news
			newsItem.html = lib.marked(newsItem.content) for newsItem in news
			res.json news

app.post '/admin/saveNews', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	newsPost =
		year: parseInt req.body.year
		date: new Date req.body.date
		title: req.body.title
		content: req.body.content
	
	if req.body._id?
		newsPost._id = new lib.mongolian.ObjectId req.body._id
	
	# todo: add error catching/reporting
	data.saveNews newsPost
	res.json { success: true }

app.post '/admin/deleteNews', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	data.deleteNews req.body
	res.json { success: true }

app.listen process.env.PORT
console.log "Express server at http://localhost:#{process.env.PORT}/ in #{process.env.NODE_ENV} mode" # printing app.settings.env doesn't work, wtf?
