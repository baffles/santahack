lib = 
	express: require 'express'
	compiler: require 'connect-compiler'
	marked: require 'marked'
	mongolian: require 'mongolian'
	mongoStore: require 'connect-mongo'
	moment: require 'moment'
	underscore: require 'underscore'
	seq: require 'seq'
	uuid: require 'node-uuid'
	knox: require 'knox'
	gm: require 'gm'
	fs: require 'fs'
	path: require 'path'
	accSso: require './acc-sso'
	data: require './data'
	pairings: require './pairings'
	voteID: require './vote-id'

_ = lib.underscore._

db = if process.env.MONGOHQ_URL? then new lib.mongolian process.env.MONGOHQ_URL else new lib.mongolian().db 'test'

s3 = lib.knox.createClient
	key: process.env.AWS_KEY
	secret: process.env.AWS_SECRET
	bucket: process.env.AWS_BUCKET
	secure: false

imageMagick = lib.gm.subClass { imageMagick: true }

accSso = new lib.accSso
data = new lib.data db
voteID = new lib.voteID 'aes256', 'santas shack hack'

app = lib.express()

app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'

app.use (req, res, next) ->
	res.locals.requestTime = new Date()
	next()

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
		clear_interval: 3600 # clear expired sessions hourly
	key: 'session'
	cookie:
		maxAge: 24 * 60 * 60 * 1000 # sessions expire in a day
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
	else if lib.data.competitionStates.Development.seq <= compState?.seq <= lib.data.competitionStates.DevelopmentGrace.seq and req.competitionEntry?.isSubmissionPartiallyComplete()
		res.locals.warnMsg = 'It looks like you haven\'t finished your submission. Please make sure to finish filling in all required information on the submission page before the end of the competition!'
		res.locals.showWarnMsg = true
	next()

# no caching for dynamic pages
app.use (req, res, next) ->
	res.setHeader "Cache-Control", "no-cache"
	next()

app.use app.router

app.use (req, res, next) ->
	res.status 404
	res.render 'error-404'

if app.settings.env is 'development'
	app.use lib.express.errorHandler
		dumpExceptions: true
		showStack: true
else
	app.use (err, req, res, next) ->
		console.log "[Server error]: #{err}"
		res.status 500
		res.render 'error-500'
	app.use (err, req, res, next) ->
		res.send 500, 'Uh oh... internal server error while processing another internal server error.'

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
	
	lib.seq()
		.seq('accUser', () -> accSso.processAuthenticationToken req.query.token, this)
		.forEach(() -> data.updateUserData @vars.accUser)
		.seq('userData', () -> data.getUserData @vars.accUser.id, this)
		.seq(() ->
			# generate user information for cookie; any data from acc overrides whatever was in DB (update may not have happened yet)
			userData = @vars.userData
			for k, v of @vars.accUser
				userData[k] = v
			
			delete userData._id # no need to store the db ID in the session
			req.session.user = userData
			res.redirect req.query.return ? '/'
		).catch((err) -> next err)

app.get '/admin', (req, res) ->
	if not req.session?.user?.isAdmin
		res.send 401, 'Unauthorized.'
		return
	
	res.render 'admin'

app.get '/info.json', (req, res, next) ->
	lib.seq()
		.seq('competition', () -> data.getDefaultCompetition this)
		.seq('participantInfo', (competition) -> competition.getParticipantInfo this)
		.seq(() ->
			now = new Date().valueOf()
			res.json
				year: @vars.competition.year
				participants: @vars.participantInfo.participants
				completeWishlists: @vars.participantInfo.completeWishlists
				hasVoted: @vars.participantInfo.hasVoted
				eligibleParticipants: @vars.participantInfo.eligibleParticipants
				blogEntries: @vars.participantInfo.blogEntries
				entriesSubmitted: 0
				currentPhase: @vars.competition.getState().jsonDisplay
				timeLeft:
						'registration-begin': (@vars.competition.registrationBegin.valueOf() - now) / 1000 | 0
						'registration-end': (@vars.competition.registrationEnd.valueOf() - now) / 1000 | 0
						'voting-begin': (@vars.competition.votingBegin.valueOf() - now) / 1000 | 0
						'voting-end': (@vars.competition.votingEnd.valueOf() - now) / 1000 | 0
						'development-begin': (@vars.competition.devBegin.valueOf() - now) / 1000 | 0
						'development-end': (@vars.competition.devEnd.valueOf() - now) / 1000 | 0
						'release-gifts': (@vars.competition.privateRelease.valueOf() - now) / 1000 | 0
						'release-public': (@vars.competition.publicRelease.valueOf() - now) / 1000 | 0
		).catch((err) -> next err)

# /home
app.get /^\/(?:\d{4}\/)?home$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.par('news', () -> data.getNews req.year, 5, (if req.query.page? then parseInt(req.query.page) * 5 else 0), this)
			.par('count', () -> data.getNewsCount req.year, this)
			.seq(() ->
				res.render 'home',
					title: "SantaHack #{req.year}"
					posts: @vars.news
					pageCount: Math.ceil @vars.count / 5
			).catch((err) -> next err)

app.get /^\/(?:\d{4}\/)?news.json$/, (req, res) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> data.getNews req.year, 5, (if req.query.page? then parseInt(req.query.page) * 5 else 0), this)
			.seq((news) ->
				for post in news
					post.utcDate = app.locals.utcDate post.date
					post.friendlyDate = app.locals.friendlyDate post.date
					post.html = app.locals.markdown post.content
				res.json news
			).catch((err) -> res.json 500, {})

# /rules
app.get /^\/(?:\d{4}\/)?rules$/, (req, res) ->
	if not req.needsYearRedirect()
		res.render 'rules',
			title: "SantaHack #{req.year} Rules"

# /participants
app.get /^\/(?:\d{4}\/)?participants$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> req.competition.getEntries this)
			.flatten()
			.parMap((entry) -> data.getUserData entry.user, this)
			.unflatten()
			.seq((participants) ->
				res.render 'participants',
					title: "SantaHack #{req.year} Participants"
					participants: _.sortBy(participants, (p) -> p.name.toLowerCase())
			).catch((err) -> next err)

# /entry
app.post /^\/(?:\d{4}\/)?entry$/, (req, res) ->
	if not req.needsYearRedirect()
		state = req.competition.getState()
		if req.body.join? and state == lib.data.competitionStates.Registration
			# join
			data.saveCompetitionEntry
				user: req.user.id
				year: req.year
			res.redirect res.locals.genLink '/wishlist'
		else if req.body.withdrawConfirm? and state.seq <= lib.data.competitionStates.Voting.seq
			data.removeCompetitionEntry req.competitionEntry
			res.redirect res.locals.genLink '/'
		else if req.body.cancel?
			res.redirect res.locals.genLink '/wishlist'
		else
			res.redirect res.locals.genLink '/wishlist'

# /withdraw
app.get /^\/(?:\d{4}\/)?withdraw$/, (req, res) ->
	if not req.needsYearRedirect()
		res.render 'withdraw',
			title: "SantaHack #{req.year}"

# /wishlist
app.get /^\/(?:\d{4}\/)?wishlist$/, (req, res) ->
	if not req.needsYearRedirect()
		entry = req.competitionEntry
		res.render 'wishlist',
			title: "SantaHack #{req.year} Wishlist"
			formVals: getWishlistFormVals req.competitionEntry
			showWarnMsg: req.competition.getState() isnt lib.data.competitionStates.Registration

app.get /^\/(?:\d{4}\/)?wishlist.json$/, (req, res) ->
	if not req.needsYearRedirect()
		res.json getWishlistFormVals req.competitionEntry

getWishlistFormVals = (entry) ->
	if entry?
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
	else
		{}

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
			.seq(() -> (req.competitionEntry?.getVoteItems this) or this())
			.seq((voteItems) ->
				voteItems = voteItems?.map (item) -> { id: voteID.toID(item), wishText: item.wishText, score: item.score }
				
				res.render 'vote',
					title: "SantaHack #{req.year} Voting"
					voteItems: _.shuffle voteItems
					startedVoting: _.any(voteItems, (vote) -> vote.score?)
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
app.get /^\/(?:\d{4}\/)?task$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> req.competitionEntry?.getAssignment this)
			.seq((task) ->
				res.render 'task',
					title: "SantaHack #{req.year} Task"
					task: task
			).catch((err) -> next err)

# /blog
app.get /^\/(?:\d{4}\/)?blog$/, (req, res, next) ->
	if not req.needsYearRedirect()
		firstPost = (if req.query.page? then parseInt(req.query.page) * 5 else 0)
		res.render 'blog',
			title: "SantaHack #{req.year} Blog"
			blogPosts: _.sortBy(req.competitionEntry?.blogPosts, 'date').reverse().slice(firstPost, firstPost + 5)
			pageCount: Math.ceil req.competitionEntry?.blogPosts?.length / 5

app.post /^\/(?:\d{4}\/)?blog$/, (req, res, next) ->
	if not req.needsYearRedirect()
		# deal with screenshots
		
		blogPost =
			date: new Date()
			author: req.user.name
			title: req.body.postTitle
			content: req.body.blogPost
		
		errors = {}
		
		uploads = []
		
		# validation
		errors.postTitle = 'Please give the blog post a title.' if not blogPost.title or blogPost.title.length == 0
		errors.blogPost = 'Please enter a blog post.' if not blogPost.content? or blogPost.content.length == 0
		
		for file in _.flatten req.files.screenshot
			if file.size > 0
				if file.type not in [ 'image/png', 'image/jpeg', 'image/gif' ]
					errors.screenshot = 'Only PNG, JPEG, and GIF images are allowed.'
				
				id = lib.uuid.v1()
				s3Name = "blogImages/#{id}"
				s3Thumb = "blogImages/#{id}_t"
				
				uploads.push
					source: file.path
					name: file.name
					type: file.type
					s3Name: s3Name
					s3Thumb: s3Thumb
		
		if Object.keys(errors).length > 0
			for upload in uploads
				lib.fs.unlink upload.source
			
			res.render 'blog',
				title: "SantaHack #{req.year} Blog"
				errors: errors
				formData:
					postTitle: req.body.postTitle
					blogPost: req.body.blogPost
				blogPosts: []
				pageCount: 1
			return
		
		if uploads.length > 0
			seq = lib.seq()
			
			uploads.forEach (upload) ->
				seq.par(() -> s3.putFile upload.source, upload.s3Name, { 'Content-Type': upload.type, 'x-amz-acl': 'public-read' }, this)
				seq.par(() ->
					# generate thumbnail
					imageMagick(upload.source)
						.quality(63)
						.resize(200)
						.write("#{upload.source}_t", (err) => if err? then this err else s3.putFile "#{upload.source}_t", upload.s3Thumb, { 'Content-Type': upload.type, 'x-amz-acl': 'public-read' }, this)
				)	
			
			seq
				.unflatten()
				.seq((results) ->
					# clean up uploads
					for upload in uploads
						lib.fs.unlink upload.source
						lib.fs.unlink "#{upload.source}_t"
					
					# check all results
					if _.every(results, (res) -> res.statusCode == 200)
						# everything is good! let's finalize the post!
						blogPost.screenshots = uploads.map (upload) -> { name: upload.name, fullsize: upload.s3Name, thumbnail: upload.s3Thumb }
						
						req.competitionEntry.addBlogPost blogPost
						res.redirect res.locals.genLink '/blog'
					else
						next "Error uploading to S3..."
				).catch(next)
		else
			req.competitionEntry.addBlogPost blogPost
			res.redirect res.locals.genLink '/blog'

# /submit
app.get /^\/(?:\d{4}\/)?submit$/, (req, res) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> req.competitionEntry?.getAssignment this)
			.seq((task) ->
				errors = req.session.submitFileErrors
				req.session.submitFileErrors = null
				res.render 'submit',
					title: "SantaHack #{req.year} Submission"
					showWarnMsg: req.competition.getState() not in [ lib.data.competitionStates.Development, lib.data.competitionStates.DevelopmentGrace ]
					entry: req.competitionEntry?.submission
					errors: errors
					task: task
			).catch((err) -> next err)

app.post /^\/(?:\d{4}\/)?submit$/, (req, res, next) ->
	if not req.needsYearRedirect()
		submission = req.competitionEntry?.submission ? {}
		
		submission.id = submission.id ? lib.uuid.v1()
		submission.name = req.body.name
		submission.website = req.body.website
		submission.description = req.body.description
		submission.privateNote = req.body.privateNote
		submission.screenshots = submission.screenshots ? []
		
		if req.body.implementsWish?
			submission.implementsWish = []
			for i in [0..req.body.implementsWish.length-1]
				submission.implementsWish[i] = req.body.implementsWish[i]?
		else
			submission.implementsWish = null
		
		thumbnails = []
		s3Uploads = []
		s3Deletes = []
		s3Folder = "submissions/#{submission.id}"
		
		fileErrors = []
		
		# source pack
		if req.files.sourcePack?.size > 0
			# user uploaded a source pack
			if req.files.sourcePack.type isnt 'application/zip' and lib.path.extname(req.files.sourcePack.name).toLowerCase() isnt '.zip'
				fileErrors.push "#{req.files.sourcePack.name} is not a zip file."
			else if req.files.sourcePack.size > req.competition.sourcePackSize
				fileErrors.push "#{req.files.sourcePack.name} is larger than #{req.competition.sourcePackSize} bytes."
			else
				s3Deletes.push submission.sourcePack.path if submission.sourcePack? # delete old
				submission.sourcePack = { name: req.files.sourcePack.name, path: "#{s3Folder}/source/#{encodeURIComponent(req.files.sourcePack.name)}", size: req.files.sourcePack.size }
				s3Uploads.push
					source: req.files.sourcePack.path
					s3Name: submission.sourcePack.path
					type: 'application/zip'
		else if req.body.deleteSourcePack?
			# user wants to delete this file
			if submission.sourcePack?
				s3Deletes.push submission.sourcePack.path
				submission.sourcePack = null
		
		# binary pack
		if req.files.binaryPack?.size > 0
			# user uploaded a binary pack
			if req.files.binaryPack.type isnt 'application/zip' and lib.path.extname(req.files.binaryPack.name).toLowerCase() isnt '.zip'
				fileErrors.push "#{req.files.binaryPack.name} is not a zip file."
			else if req.files.binaryPack.size > req.competition.binaryPackSize
				fileErrors.push "#{req.files.binaryPack.name} is larger than #{req.competition.binaryPackSize} bytes."
			else
				s3Deletes.push submission.binaryPack.path if submission.binaryPack? # delete old
				submission.binaryPack = { name: req.files.binaryPack.name, path: "#{s3Folder}/binary/#{encodeURIComponent(req.files.binaryPack.name)}", size: req.files.binaryPack.size }
				s3Uploads.push
					source: req.files.binaryPack.path
					s3Name: submission.binaryPack.path
					type: 'application/zip'
		else if req.body.deleteBinaryPack?
			# user wants to delete this file
			if submission.binaryPack?
				s3Deletes.push submission.binaryPack.path
				submission.binaryPack = null
		
		# new screenshots
		for file in _.flatten req.files.screenshot
			if file.size > 0
				if file.type not in [ 'image/png', 'image/jpeg', 'image/gif' ]
					fileErrors.push "#{file.name} is not a PNG, JPEG, or GIF."
				else
					id = lib.uuid.v1()
					s3Name = "#{s3Folder}/screenshots/#{id}"
					s3Thumb = "#{s3Folder}/screenshots/#{id}_t"
					
					screenshot =
						id: id
						name: file.name
						fullsize: s3Name
						thumbnail: s3Thumb
					
					submission.screenshots.push screenshot
					
					s3Uploads.push
						source: file.path
						s3Name: s3Name
						type: file.type
					
					thumbnails.push
						source: file.path
						s3Name: s3Thumb
						type: file.type
		
		# deleted screenshots
		for toDelete in _.filter(submission.screenshots, (screenshot) -> req.body.deleteScreenshot?[screenshot.id]?)
			s3Deletes.push toDelete.fullsize
			s3Deletes.push toDelete.thumbnail
		submission.screenshots = _.reject submission.screenshots, (screenshot) -> req.body.deleteScreenshot?[screenshot.id]?
		
		# process s3 uploads/deletes
		seq = lib.seq()
		
		s3Deletes.forEach (deleted) -> seq.par () -> s3.deleteFile deleted, this
		seq.seq(() -> this()) # wait for deletes
		
		s3Uploads.forEach (upload) -> seq.par(() -> s3.putFile upload.source, upload.s3Name, { 'Content-Type': upload.type, 'x-amz-acl': 'public-read' }, this)
		
		thumbnails.forEach (thumbnail) ->
			seq.par(() ->
				# generate thumbnail
				imageMagick(thumbnail.source)
					.quality(63)
					.resize(200)
					.write("#{thumbnail.source}_t", (err) => if err? then this err else s3.putFile "#{thumbnail.source}_t", thumbnail.s3Name, { 'Content-Type': thumbnail.type, 'x-amz-acl': 'public-read' }, this)
			)
		
		seq
			.unflatten()
			.seq((results) ->
				# clean up temp files from disk
				for file in _.flatten req.files
					lib.fs.unlink file.path
				for thumbnail in thumbnails
					lib.fs.unlink "#{thumbnail.source}_t"
				
				# check all results
				if _.every(results, (res) -> res.statusCode == 200)
					# everything is good! let's finalize this submission!
					req.competitionEntry.saveSubmission submission
					req.session.submitFileErrors = fileErrors
					res.redirect res.locals.genLink '/submit'
				else
					console.log "Error interacting with s3, results: ", results
					next "Error interacting with S3..."
			).catch(next)

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
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
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
		sourcePackSize: parseInt req.body.sourcePackSize
		binaryPackSize: parseInt req.body.binaryPackSize
		rules: req.body.rules
	
	data.saveCompetition competition
	res.json { success: true }

app.get '/admin/getNews', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	
	data.getAllNews parseInt(req.query.year), (err, news) ->
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

app.get '/admin/getWishes', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return
	
	lib.seq()
		.seq(() -> data.getWishes parseInt(req.query.year), this)
		.seq((wishes) ->
			wishes = wishes.map (wish) -> { id: voteID.toID(wish), wishText: wish.wishText, isListComplete: wish.isListComplete }
			res.json wishes
		).catch((err) ->
			res.json 500, { success: false, error: err }
		)

app.post '/admin/saveWishes', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return
	
	wishes = []
	
	for id, text of req.body
		item = voteID.fromID(id)
		if item?.destUser? and item?.wish?
			wishes.push { destUser: item.destUser, wish: item.wish, wishText: text }
	
	# todo: add error catching/reporting
	data.saveWishes parseInt(req.query.year), wishes
	
	res.json { success: true }

app.get '/admin/getEligibility', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return
	
	lib.seq()
		.seq(() -> data.getEligibility parseInt(req.query.year), this)
		.seq((eligibility) -> res.json eligibility)
		.catch((err) -> res.json 500, { success: false, error: err })

app.post '/admin/updateEligibility', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return
	if not req.body.mode?
		res.json { success: false, error: 'Missing mode in body' }
		return
	
	switch req.body.mode
		when 'update' then data.updateEligibility parseInt req.query.year
		when 'clear' then data.clearEligibility parseInt req.query.year

	res.json { success: true }

app.post '/admin/runPairing', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return
	
	lib.seq()
		.seq('votes', () -> data.getEligibleWishVotes parseInt(req.query.year), this)
		.seq('canDev', () -> data.getCanDevInfo parseInt(req.query.year), this)
		.seq(() ->
			votes = @vars.votes
			canDev = {}
			prefOS = {}
			
			for user in @vars.canDev
				prefOS[user.user] = user.wishlist.preferredOS
				canDev[user.user] = cdr = {}
				cdr['windows'] = user.wishlist.canDev.indexOf('windows') >= 0
				cdr['linux'] = user.wishlist.canDev.indexOf('linux') >= 0
				cdr['osx'] = user.wishlist.canDev.indexOf('mac') >= 0
			
			if votes.length > 0
				# i hate that this is so unreadable, but it maps the huge list of individual wish votes into an array of { sourceUser, destUser, wishlistScore: average of wish votes }
				scores = _.flatten _.map _.groupBy(votes, 'sourceUser'), (set, sourceUser) -> _.map _.groupBy(set, 'destUser'), (votes, destUser) -> { sourceUser, destUser, wishlistScore: _.reduce(votes.map((vote) -> vote.score), ((sum, score) -> sum + score), 0) / votes.length }
			
				# find optimal pairings
				results = lib.pairings.optimizePairings scores, canDev, prefOS
			
				# store results
				data.savePairings parseInt(req.query.year), results
			
				# display result summary
				averagePairingScore = Math.round((_.reduce(results, ((sum, pair) -> sum + pair.wishlistScore), 0) / (10 * results.length)) * 100) / 100
				averageVoteScore = Math.round((_.reduce(scores, ((sum, vote) -> sum + vote.wishlistScore), 0) / scores.length) * 100) / 100
				maxVoteScores = _.map(_.groupBy(scores, 'sourceUser'), (set) -> _.reduce(set, ((max, vote) -> Math.max(max, vote.wishlistScore)), 0))
				averageMaxVoteScore = Math.round((_.reduce(maxVoteScores, ((sum, score) -> sum + score), 0) / maxVoteScores.length) * 100) / 100
				aboveAveragePercent = Math.round (averagePairingScore * 100 / averageVoteScore) - 100
				percentOfMax = Math.round averagePairingScore * 100 / averageMaxVoteScore
			
				res.json { success: true, summary: "Pairing complete.\n\nAverage pairing score: #{averagePairingScore}\nAverage overall wishlist score: #{averageVoteScore}\nAverage top-choice score: #{averageMaxVoteScore}\nOn average, #{aboveAveragePercent}% above average vote\nOn average, pairing was scored #{percentOfMax}% of most-desired score" }
			else
				res.json { success: true, summary: 'Nothing done; not enough eligible participants.' }
		).catch((err) -> res.json 500, { success: false, error: err })

app.listen process.env.PORT
console.log "Express server at http://localhost:#{process.env.PORT}/ in #{process.env.ENV} mode" # printing app.settings.env doesn't work, wtf?
