$ () ->
	$('.pagination a').click (e) ->
		e.preventDefault()
		page = parseInt $(this).attr 'data-page'
		
		$.ajax
			url: "news.json?page=#{page}"
			success: (news) ->
				$news = $('#news')
				$news.empty()
				
				for post in news
					$post = $('<div>').addClass 'news-item'
					$post.append $('<h3>').text post.title
					$post.append $('<span>').addClass('date').attr('title', post.utcDate).text "Posted #{post.friendlyDate}"
					$post.append $('<span>').html post.html
					$news.append $post
				
				$.scrollTo $news
			error: (req, status, errMsg) ->
				alert "Error loading news: #{status}\n#{errMsg}"
