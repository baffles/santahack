lib = 
	express: require 'express'
	compiler: require 'connect-compiler'

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

app.use lib.express.bodyParser()
app.use lib.express.methodOverride()
app.use app.router

if app.settings.env = 'development'
	app.use lib.express.errorHandler
		dumpExceptions: true
		showStack: true
else
	app.use lib.express.errorHandler 

###
app.get '/', (req, res) ->
	res.render 'index',
		title: 'Express'
###

app.get '*', (req, res) ->
	res.render 'renovations'

app.get '/test', (req, res) ->
	res.render 'test',
		title: 'Test'

app.listen process.env.PORT
console.log "Express server at http://localhost:%d/ in %s mode", process.env.PORT, app.settings.env
