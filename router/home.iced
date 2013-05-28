# Homepage

module.exports =
	register: (app, data) ->
		# /
		app.get /^\/(\d{4})?\/?$/, (req, res) ->
			if req.params[0]?
				res.redirect "/#{req.params[0]}/home"
			else
				res.redirect '/home'

		# /home
		app.get /^\/(?:\d{4}\/)?home(?:\/(\d+))?$/, (req, res, next) ->
			if not req.needsYearRedirect()
				page = req.params[0]
				await
					data.getNews req.year, 5, (if page? then parseInt(page) * 5 else 0), defer newsErr, news
					data.getNewsCount req.year, defer countErr, count

				if newsErr?
					next newsErr
					return
				
				if countErr?
					next countErr
					return

				res.render 'home',
					title: "SantaHack #{req.year}"
					posts: news
					pageCount: Math.ceil count / 5

		# /news.json
		app.get /^\/(?:\d{4}\/)?news.json$/, (req, res) ->
			if not req.needsYearRedirect()
				await
					data.getNews req.year, 5, (if req.query.page? then parseInt(req.query.page) * 5 else 0), defer err, news

				if err?
					res.json 500, {}
					return
				
				for post in news
						post.utcDate = app.locals.utcDate post.date
						post.friendlyDate = app.locals.friendlyDate post.date
						post.html = app.locals.markdown post.content
					res.json news