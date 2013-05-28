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
	data: require './lib/data'
	pairings: require './lib/pairings'
	voteID: require './lib/vote-id'

# make sure iced coffeescript gets loaded, so it can handle .iced files
require 'iced-coffee-script'

_ = lib.underscore._

db = if process.env.MONGOHQ_URL? then new lib.mongolian process.env.MONGOHQ_URL else new lib.mongolian().db 'test'

s3 = lib.knox.createClient
	key: process.env.AWS_KEY
	secret: process.env.AWS_SECRET
	bucket: process.env.AWS_BUCKET
	secure: false

imageMagick = lib.gm.subClass { imageMagick: true }

data = new lib.data db
voteID = new lib.voteID 'aes256', 'santas shack hack'

app = lib.express()

app.set 'views', "#{__dirname}/views"
app.set 'view engine', 'jade'

(require './middleware').register app, data
(require './lib/app-locals').register app
(require './router').register app, data

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
				entriesSubmitted: @vars.participantInfo.entriesSubmitted
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
			).catch next

# /blog
app.get /^\/(?:\d{4}\/)?blog(?:\/(\d+))?$/, (req, res, next) ->
	if not req.needsYearRedirect()
		page = req.params[0]
		firstPost = (if page? then parseInt(page) * 5 else 0)
		posts = _.sortBy(req.competitionEntry?.blogPosts, 'date').reverse()
		res.render 'blog',
			title: "SantaHack #{req.year} Blog"
			ownBlog: true
			blogBase: '/blog'
			blogPosts: posts.slice(firstPost, firstPost + 5)
			pageCount: Math.ceil posts.length / 5

app.get /^\/(?:\d{4}\/)?blog.json$/, (req, res) ->
	if not req.needsYearRedirect()
		page = req.query.page
		firstPost = (if page? then parseInt(page) * 5 else 0)
		posts = _.sortBy(req.competitionEntry?.blogPosts, 'date').reverse().slice(firstPost, firstPost + 5)
		
		for post in posts
			post.utcDate = app.locals.utcDate post.date
			post.friendlyDate = app.locals.friendlyDate post.date
			post.html = app.locals.markdown post.content
		
		res.json posts

app.get /^\/(?:\d{4}\/)?blog\/edit\/([\w\-]+)$/, (req, res, next) ->
	id = req.params[0]
	post = _.first _.where req.competitionEntry.blogPosts, { id }
	if post? and lib.data.competitionStates.Development.seq <= req.competition.getState().seq <= lib.data.competitionStates.DevelopmentGrace.seq
		res.render 'blog',
			title: "SantaHack #{req.year} Blog"
			ownBlog: true
			blogBase: '/blog'
			editPost: post
			previewPost: post
			lastScreenshots: JSON.stringify post.screenshots
	else
		res.redirect res.locals.genLink '/blog'

app.get /^\/(?:\d{4}\/)?blog\/delete\/([\w\-]+)$/, (req, res, next) ->
	id = req.params[0]
	post = _.first _.where req.competitionEntry.blogPosts, { id }
	if post?
		res.render 'blog-delete',
			title: "SantaHack #{req.year} Delete Blog Post"
			blogBase: '/blog'
			post: post
	else
		res.redirect res.locals.genLink '/blog'

app.get /^\/(?:\d{4}\/)?blog\/user\/([\w\-]+)(?:\/(\d+))?$/, (req, res, next) ->
	id = req.params[0]
	page = req.params[1]
	if req.user?.id is id or req.competition.getState() is lib.data.competitionStates.ReleasePublic or (req.competition.getState() is lib.data.competitionStates.ReleasePrivate and (req.competitionEntry?.gift?.user is id or req.competitionEntry?.gift?.original is id))
		lib.seq()
			.par('entry', () -> data.getUserCompetitionEntry { id }, req.competition, this)
			.par('userData', () -> data.getUserData id, this)
			.seq(() ->
				firstPost = (if page? then parseInt(page) * 5 else 0)
				posts = _.sortBy(@vars.entry?.blogPosts, 'date').reverse()
				res.render 'blog',
					title: "SantaHack #{req.year} Blog: #{@vars.userData.name}"
					ownBlog: false
					blogBase: "/blog/user/#{id}"
					userName: @vars.userData.name
					blogPosts: posts.slice firstPost, firstPost + 5
					pageCount: Math.ceil posts.length / 5
			).catch next
	else
		res.redirect res.locals.genLink '/'

app.get /^\/(?:\d{4}\/)?blog\/post\/([\w\-]+)(?:\/(\d+))?$/, (req, res, next) ->
	id = req.params[0]
	lib.seq()
		.seq(() -> data.getBlogPost id, this)
		.seq((post) ->
			res.render 'blog',
				title: "SantaHack #{req.year} Blog Post"
				ownBlog: false
				blogBase: '/blog'
				blogPosts: [ post ]
				pageCount: 0
		).catch next

app.post /^\/(?:\d{4}\/)?blog\/delete\/([\w\-]+)$/, (req, res, next) ->
	id = req.params[0]
	post = _.find req.competitionEntry.blogPosts, (post) -> post.id is id
	if post? and lib.data.competitionStates.Development.seq <= req.competition.getState().seq <= lib.data.competitionStates.DevelopmentGrace.seq
		if req.body.delete?
			post.screenshots.forEach (screenshot) ->
				s3.deleteFile screenshot.fullsize, () -> # just issue the request, don't care what happens
				s3.deleteFile screenshot.thumbnail, () ->
			
			req.competitionEntry.deleteBlogPost post
	
	res.redirect res.locals.genLink '/blog'

app.post /^\/(?:\d{4}\/)?blog$/, (req, res, next) ->
	if not req.needsYearRedirect()
		if lib.data.competitionStates.Development.seq <= req.competition.getState().seq <= lib.data.competitionStates.DevelopmentGrace.seq
			previewOnly = req.body.preview?
		
			blogPost =
				date: if req.body.id? and req.body.date? then new Date(JSON.parse(req.body.date)) else new Date()
				id: req.body.id
				author: req.user.name
				title: req.body.title
				screenshots: if req.body.lastScreenshots? then JSON.parse(req.body.lastScreenshots) else []
				content: req.body.content
		
			uploads = []
			deletes = []
		
			errors =
				postTitle: false
				blogPost: false
		
			errorText = []
			validPost = true
		
			# validation
			if not blogPost.title or blogPost.title.length == 0
				errors.title = true
				errorText.push 'Please give the blog post a title.'
				validPost = false
		
			if not blogPost.content? or blogPost.content.length == 0
				errors.content = true
				errorText.push 'Please enter a blog post.'
				validPost = false
		
			# new screenshots
			for file in _.flatten req.files.screenshot
				if file.size > 0
					if file.type not in [ 'image/png', 'image/jpeg', 'image/gif' ]
						errorText.push "#{file.name} is not a PNG, JPEG, or GIF."
					else
						id = lib.uuid.v1()
						s3Name = "blogImages/#{id}"
						s3Thumb = "blogImages/#{id}_t"
					
						screenshot =
							id: id
							name: file.name
							fullsize: s3Name
							thumbnail: s3Thumb
					
						blogPost.screenshots.push screenshot
					
						uploads.push
							source: file.path
							name: file.name
							type: file.type
							s3Name: s3Name
							s3Thumb: s3Thumb
		
			# deleted screenshots
			for toDelete in _.filter(blogPost.screenshots, (screenshot) -> req.body.deleteScreenshot?[screenshot.id]?)
				deletes.push toDelete.fullsize
				deletes.push toDelete.thumbnail
			blogPost.screenshots = _.reject blogPost.screenshots, (screenshot) -> req.body.deleteScreenshot?[screenshot.id]?
		
			# process s3 uploads/deletes
			seq = lib.seq()
		
			deletes.forEach (deleted) -> seq.par () -> s3.deleteFile deleted, this
			seq.seq(() -> this()) # wait for deletes
		
			uploads.forEach (image) ->
				seq.par(() -> s3.putFile image.source, image.s3Name, { 'Content-Type': image.type, 'x-amz-acl': 'public-read' }, this)
				seq.par(() ->
					# generate thumbnail and upload
					imageMagick(image.source)
						.quality(63)
						.resize(200)
						.write("#{image.source}_t", (err) => if err? then this err else s3.putFile "#{image.source}_t", image.s3Thumb, { 'Content-Type': image.type, 'x-amz-acl': 'public-read' }, this)
				)
		
			seq
				.unflatten()
				.seq((results) ->
					# clean up temp files from disk
					for file in _.flatten req.files
						lib.fs.unlink file.path
					for image in uploads
						lib.fs.unlink "#{image.source}_t"
				
					# check all results
					if _.every(results, (res) -> res.statusCode == 200)
						# save/edit as appropriate
						if validPost and not previewOnly
							if blogPost.id?
								# save edit
								req.competitionEntry.updateBlogPost blogPost
							else
								# save new post
								blogPost.id = lib.uuid.v1()
								req.competitionEntry.addBlogPost blogPost
					
						if previewOnly or errorText.length > 0
							# show edit page for post; if post itself was valid then we save it
							res.render 'blog',
								title: "SantaHack #{req.year} Blog"
								ownBlog: true
								blogBase: '/blog'
								editPost: blogPost
								previewPost: blogPost
								lastScreenshots: if not validPost or previewOnly then JSON.stringify(blogPost.screenshots) else null
								errors: errors
								errorText: errorText
						else
							# redirect
							res.redirect res.locals.genLink '/blog'
					else
						console.log "Error interacting with s3, results: ", results
						next "Error interacting with S3..."
				).catch(next)
		else
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
app.get /^\/(?:\d{4}\/)?gift$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.par('gift', () -> if req.competitionEntry? then req.competitionEntry.getGift this else this null, null)
			.par('secretSanta', () -> if req.competitionEntry?.gift?.user? then data.getUserData req.competitionEntry.gift.user, this else this null, null)
			.par('originalSanta', () -> if req.competitionEntry?.gift?.original? then data.getUserData req.competitionEntry.gift.original, this else this null, null)
			.par('giftWishlist', () -> if req.competitionEntry?.gift?.user? then data.getUserWishlist req.competitionEntry?.gift?.user, req.year, this else this null, null)
			.seq(() -> this null, null) # do the above before the blow
			.par('giftEntry', () -> if @vars.secretSanta? then data.getUserCompetitionEntry @vars.secretSanta, req.competition, this else this null, null)
			.par('originalEntry', () -> if @vars.originalSanta? then data.getUserCompetitionEntry @vars.originalSanta, req.competition, this else this null, null)
			.seq(() ->
				res.render 'gift',
					title: "SantaHack #{req.year} Gift"
					giftData: @vars.gift
					giftWishlist: @vars.giftWishlist
					secretSanta: @vars.secretSanta
					originalSanta: @vars.originalSanta
					giftEntry: @vars.giftEntry
					originalEntry: @vars.originalEntry
			).catch next

# /downloads
app.get /^\/(?:\d{4}\/)?downloads$/, (req, res, next) ->
	if not req.needsYearRedirect()
		lib.seq()
			.seq(() -> data.getCompleteSubmissions req.competition.year, this)
			.flatten()
			.parMap((submission) -> data.getUserData submission.user, (err, user) =>
				submission.user = user
				this err, submission
			).parMap((submission) -> data.getUserData submission.assignment, (err, assn) =>
				submission.assignment = assn
				this err, submission
			).seqMap((submission) -> data.getUserWishlist submission.assignment.id, req.competition.year, (err, wishlist) =>
				submission.wishlist = wishlist
				this err, submission
			).unflatten()
			.seq((entries) ->
				res.render 'downloads',
					title: "SantaHack #{req.year} Downloads"
					entries: entries
			).catch next

# admin functions
# TODO: should do better w/ check errors from DB on updates/saves on admin pages
# TODO: add function to remove orphaned s3 uploads (or do that in cake?)
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
		
app.post '/admin/runGifting', (req, res) ->
	if not req.session?.user?.isAdmin
		res.json 401, { success: false, error: 'Unauthorized' }
		return
	if not req.query.year?
		res.json { success: false, error: 'Missing year parameter' }
		return

	lib.seq()
		.par('completeSubmissions', () -> data.getCompleteSubmissions parseInt(req.query.year), this)
		.par('pairings', () -> data.getPairings parseInt(req.query.year), this)
		.seq(() ->
			giftPairing = {}
			errors = []
			
			for complete in @vars.completeSubmissions
				giftPairing[complete.assignment] = { user: complete.user, isOriginal: true }
			
			for incomplete in _.reject(@vars.pairings, (pairing) -> giftPairing[pairing.assignment]?)
				# assign a gift for pairing.assignment
				rec = _.find @vars.pairings, (pairing) -> pairing.user is incomplete.assignment
				
				# score each completed submission for this user
				submissionScores = []
				for submission in @vars.completeSubmissions
					if submission.user isnt incomplete.assignment
						wishlist = submission.assignment
						wishes = _.map submission.submission.implementsWish, (val, idx) -> if val then idx else null
						wishes = _.filter wishes, (val) -> val?
					
						# TODO: take into account platform matches between submission's original wishlist, and the user being assigned
						votes = _.map wishes, (wish) -> _.find rec.votesCast, (vote) -> vote.destUser is wishlist and vote.wish is wish
					
						submissionScores.push { submission: submission.user, score: _.reduce(votes, ((sum, vote) -> sum + vote), 0) / votes.length }
				
				# find and assign best pairing
				if submissionScores.length > 0
					newAssignment = _.sortBy(submissionScores, 'score')[0].submission
					giftPairing[incomplete.assignment] = { user: newAssignment, isOriginal: false, original: incomplete.user }
				else
					errors.push "No possible gift pairings for user #{incomplete.assignment}."
					giftPairing[incomplete.assignment] = { error: 'No possible pairings.' }
			
			data.saveGiftings parseInt(req.query.year), giftPairing
			
			if errors.length is 0
				res.json { success: true, summary: 'Gifting complete.' }
			else
				res.json { success: true, summary: "Gifting complete, with following errors:\n#{errors.join('\n')}" }
		).catch((err) -> res.json 500, { success: false, error: err })

app.listen process.env.PORT
console.log "Express server at http://localhost:#{process.env.PORT}/ in #{process.env.ENV} mode" # printing app.settings.env doesn't work, wtf?
