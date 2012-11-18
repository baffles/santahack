lib = 
	express: require 'express'
	compiler: require 'connect-compiler'
	marked: require 'marked'
	mongolian: require 'mongolian'
	moment: require 'moment'
	accSso: require './acc-sso'
	data: require './data'

db = if process.env.MONGOHQ_URL then new lib.mongolian process.env.MONGOHQ_URL else new lib.mongolian().db 'test'

accSso = new lib.accSso
data = new lib.data db

app = lib.express()

app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'

app.use lib.express.favicon "#{__dirname}/public/images/favicon.ico"

app.use lib.compiler
	enabled: [ 'coffee', 'stylus', 'uglify', 'jade' ]
	src: 'assets'
	dest: 'assets/compiled'
	mount: '/static'
app.use '/static', lib.express.static "#{__dirname}/public"
app.use '/static', lib.express.static "#{__dirname}/assets/compiled"

app.use lib.express.cookieParser()
app.use lib.express.session
	secret: 'trolololol'
app.use lib.express.bodyParser()
app.use lib.express.methodOverride()

# add year to request object, if there is one. add a year redirect convenience function for pages that need a year
app.use (req, res, next) ->
	yearMatch = req.path.match(/^\/(\d{4})\//)
	req.year = res.locals.year = parseInt(yearMatch[1]) if yearMatch?
	res.locals.genLink = (path) -> "/#{req.year}#{path}"
	req.needsYearRedirect = () ->
		if not req.year?
			data.getDefaultYear (err, year) ->
				throw err if err
				res.redirect "/#{year}#{req.path}"
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
		data.getCompetition req.year, (err, competition) ->
			res.locals.competition = competition
			res.locals.competitionStates = lib.data.competitionStates
			next(err)
	else
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
	returnUrl = req.param 'return'
	accReturn = process.env.ACCRETURN ? "http://#{req.host}/login-return"
	accReturn += "$return=#{returnUrl}" if returnUrl?
	res.redirect accSso.getLoginUrl accReturn

app.get '/logout', (req, res) ->
	req.session.user = null
	res.redirect (req.param 'return') ? '/'

app.get '/login-return', (req, res, next) ->
	req.session.user = null

	accSso.processAuthenticationToken (req.param 'token'), (accErr, accUser) ->
		if accErr?
			next(accErr)
		else
			data.updateUserData accUser
			data.getUserData accUser.id, (err, user) ->
				if err?
					next(err)
				else
					req.session.user = user
					res.redirect (req.param 'return') ? '/'

app.get '/admin', (req, res) ->
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
				next(err)
			else
				res.render 'home',
					title: 'SantaHack'
					posts: news

app.get /^\/(?:\d{4}\/)?years$/, (req, res) ->
	if not req.needsYearRedirect()
		#data.getCompetition req.year, (err, competition) ->
			res.send res.locals.competition.getState()
	#	competitionHelper.getCompetitionList (err, years) ->
			#res.send JSON.stringify years

# /rules
app.get /^\/(?:\d{4}\/)?rules$/, (req, res) ->
	if not req.needsYearRedirect()
		res.render 'rules',
			title: 'SantaHack'

# /participants

# /join

# /withdraw

# /wishlist

# /vote

# /task

# /submit

# /gift

# /downloads

#! add log page

# admin functions
#add auth checking! and maybe check errors from DB on updates/saves
app.get '/admin/getCompetitionList', (req, res) ->
	data.getCompetitionList (err, years) ->
		if err?
			res.json 500, err
		else
			res.json years

app.get '/admin/getCompetition', (req, res) ->
	data.getCompetition parseInt(req.param 'year'), (err, comp) ->
		if err?
			res.json 500, err
		else
			comp._id = undefined # we don't want to send this crap
			res.json comp

app.post '/admin/saveCompetition', (req, res) ->
	data.saveCompetition req.body
	res.json { success: true }
	
	#res.json
	#	success: false
	#	error: 'you suck'

app.get '/admin/getNews', (req, res) ->
	data.getNews parseInt(req.param 'year'), 0, (err, news) ->
		if err?
			res.json 500, err
		else
			newsItem._id = newsItem._id.toString() for newsItem in news
			newsItem.html = lib.marked(newsItem.content) for newsItem in news
			res.json news

app.post '/admin/saveNews', (req, res) ->
	data.saveNews req.body
	res.json { success: true }

app.post '/admin/deleteNews', (req, res) ->
	data.deleteNews req.body
	res.json { success: true }

app.listen process.env.PORT
console.log "Express server at http://localhost:%d/ in %s mode", process.env.PORT, app.settings.env
