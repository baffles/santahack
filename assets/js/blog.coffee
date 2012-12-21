$ () ->
	$ssLabel = $ '#screenshotsLabel'
	$ssLabel.append '(s) ['
	$ssLabel.append $addSSLink = $('<a>').attr('href', '#').attr('title', 'Add more upload slots').text('+')
	$ssLabel.append ']'
	
	$ssFiles = $ '#screenshots'
	
	$addSSLink.click (e) ->
		e.preventDefault()
		$ssFiles.append $('<input>').attr('type', 'file').attr('name', 'screenshot[]')
	
	$('#postButton').click (e) ->
		$(this).button 'posting'
		# setTimeout, because calling button() does the same, otherwise our disable gets squashed
		setTimeout (=> $(this).attr 'disabled', 'disabled'), 1
	
	$('#previewButton').click (e) ->
		$(this).button 'previewing'
		# setTimeout, because calling button() does the same, otherwise our disable gets squashed
		setTimeout (=> $(this).attr 'disabled', 'disabled'), 1
	
	$('.lightbox').lightbox
		fitToScreen: true
		loopImages: true
		fileLoadingImage: '/static/lib/lightbox/images/loading.gif'
		fileBottomNavCloseImage: '/static/lib/lightbox/images/closelabel.gif'
		displayDownloadLink: true
	
	###
	# note to self: on ajax pagination, deal with lightboxes
	$('.pagination a').click (e) ->
		e.preventDefault()
		page = parseInt $(this).attr 'data-page'
		
		$.ajax
			url: "blog.json?page=#{page}"
			success: (posts) ->
				$blog = $('#blog')
				$blog.empty()
				
				for post in posts
					# TODO: emit proper output.
					$post = $('<div>').addClass 'blog-post'
					$post.append $('<h3>').text post.title
					$post.append $('<span>').addClass('date').attr('title', post.utcDate).text "Posted #{post.friendlyDate}"
					$post.append $('<span>').html post.html
					$news.append $post
				
				$.scrollTo $news
			error: (req, status, errMsg) ->
				alert "Error loading news: #{status}\n#{errMsg}"
	###
