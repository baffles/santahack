# database update tool

option '-d', '--database [db]', 'database connection string'

task 'database:updateblog', 'update blog posts in database to assign IDs where required', (options) ->
	mongolian = require 'mongolian'
	uuid = require 'node-uuid'
	dbUrl = options.database ? process.env.MONGOHQ_URL
	
	if not dbUrl?
		console.log 'Need a mongo URL to connect to.'
		process.exit 1
	
	db = new mongolian dbUrl
	entriesCollection = db.collection('entries')
	
	console.log "Database blog update on #{dbUrl}"
	console.log ''
	
	console.log 'Fetching all blog posts...'
	
	entriesCollection.find({}).toArray (err, entries) ->
		console.log err if err?
		
		if entries?
			console.log 'Updating blog posts and screenshots with IDs as necessary...'
			
			for entry in entries
				updated = false
				
				if entry.blogPosts?
					for post in entry.blogPosts
						if not post.id?
							post.id = uuid.v1()
							updated = true
						
						if post.screenshots?
							for ss in post.screenshots
								if not ss.id?
									ss.id = uuid.v1()
									updated = true
				
				if updated
					entriesCollection.update { year: entry.year, user: entry.user }, { $set: { blogPosts: entry.blogPosts } }
	
		console.log ''
		console.log 'Update complete.'
		
		process.exit 0
