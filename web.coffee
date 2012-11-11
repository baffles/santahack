lib = 
	express: require 'express'
	compiler: require 'connect-compiler'
	marked: require 'marked'
	mongolian: require 'mongolian'
	moment: require 'moment'
	querystring: require 'querystring'
#	connect: require 'connect'
	https: require 'https'
	xml2js: require 'xml2js'

db = if process.env.MONGOHQ_URL then new lib.mongolian process.env.MONGOHQ_URL else new lib.mongolian().db 'test'

app = lib.express()

app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'

app.use lib.express.favicon "#{__dirname}/public/images/favicon.ico"

app.use lib.compiler
	enabled: [ 'coffee', 'less', 'uglify' ]
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

app.use (req, res, next) ->
	yearMatch = req.path.match(/^\/(\d{4})\//)
	req.year = res.locals.year = parseInt(yearMatch[1]) if yearMatch?
	res.locals.genLink = (path) -> "/#{req.year}#{path}"
	req.needsYearRedirect = () ->
		if not req.year?
			db.collection('years').find({}, { year: 1 }).sort({ year: -1 }).limit(1).toArray (err, year) ->
				throw err if err
				res.redirect "/#{year[0].year}#{req.path}"
			return true
		else
			return false
	next()

app.use (req, res, next) ->
	res.locals.session = req.session
	res.locals.returnURL = req.path
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
	accReturn = "http://#{req.host}/login-return"
	accReturn += "$return=#{returnUrl}" if returnUrl?
	res.redirect "http://www.allegro.cc/account/login/#{accReturn}"

app.get '/logout', (req, res) ->
	req.session.user = undefined
	res.redirect (req.param 'return') ? '/'

app.get '/login-return', (req, res) ->
	# add error handling on all paths out
	loginToken = req.param 'token'
	req.session.user = undefined

	if loginToken?
		lib.https.get "https://www.allegro.cc/account/authenticate-token/#{loginToken}", (response) ->
			resBody = ''

			response.on 'data', (chunk) ->
				resBody += chunk

			response.on 'end', () ->
				parser = new lib.xml2js.Parser()
				parser.addListener 'end', (loginInfo) ->
					if loginInfo.response.$.valid == 'true'
						user =
							id: loginInfo.response.member[0].$.id
							name: loginInfo.response.member[0].name[0]
							avatar: loginInfo.response.member[0].avatar[0]._
							picture: loginInfo.response.member[0].picture[0]._

						db.collection('users').update { id: user.id }, user, true, false

						req.session.user = user

						res.redirect (req.param 'return') ? '/'

				parser.parseString resBody

# /home
app.get /^\/(?:\d{4}\/)?home$/, (req, res) ->
	if not req.needsYearRedirect()
		db.collection('news').find({ year: req.year }).sort({ date: -1}).limit(5).toArray (err, news) ->
			throw err if err
			res.render 'home',
				title: 'SantaHack'
				posts: news

# /rules
app.get /^\/(?:\d{4}\/)?rules$/, (req, res) ->
	if not req.needsYearRedirect()
		db.collection('years').find({ year: req.year }, { rules: 1 }).limit(1).toArray (err, year) ->
			throw err if err
			res.render 'rules',
				title: 'SantaHack'
				rules: year[0].rules

app.listen process.env.PORT
console.log "Express server at http://localhost:%d/ in %s mode", process.env.PORT, app.settings.env
