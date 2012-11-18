class NewsTab extends Tab
	constructor: () ->
		@$newsTable = null
		@newsFormHtml = null
		@newsDelConfHtml = null
		
		super '/static/admin/tabs/news.html', (container) =>
			@$newsTable = $('#newsTBody:first', @$container)
			
			$('#addNewsButton', @$container).click @editNewsPostClick null
			
			if @curYear?
				@loadData @curYear
	
	editNewsPostClick: (newsItem) -> () =>
		openPopup = () =>
			$popup = $(@newsFormHtml)
			$('#label', $popup).text if newsItem? then 'Edit News Post' else 'Add News Post'
			$saveButton = $('#saveButton', $popup)
			
			$newsDate = $('#editNewsForm #newsDate', $popup)
			$newsTitle = $('#editNewsForm #newsTitle', $popup)
			$newsPost = $('#editNewsForm #newsPost', $popup)
			
			$validationAlert = $('#validationAlert', $popup)
			$('button.close', $validationAlert).click () ->
				$validationAlert.slideUp 'fast'
			
			$newsDate.val moment(newsItem?.date)?.format dateFormat
			$newsTitle.val newsItem?.title
			$newsPost.val newsItem?.content

			# validation
			$newsDate.keyup () ->
				valid = moment($(this).val(), dateFormat)?.isValid()

				$($(this).parents('.control-group').get 0)
					.removeClass('warning error info success')
					.addClass if valid then 'success' else 'error'

				$($(this).siblings('.help-inline').get 0).text if valid then '' else "#{dateFormat} (e.g., #{new moment().format dateFormat})"

			$newsTitle.blur () ->
				valid = $(this).val().length > 0

				$($(this).parents('.control-group').get 0)
					.removeClass('warning error info success')
					.addClass if valid then 'success' else 'error'

				$($(this).siblings('.help-inline').get 0).text if valid then '' else 'Enter a title'
			
			$newsPost.blur () ->
				valid = $(this).val().length > 0

				$($(this).parents('.control-group').get 0)
					.removeClass('warning error info success')
					.addClass if valid then 'success' else 'error'

			# enable tab in content textbox (for markdown)
			$popup.delegate '#newsPost', 'keydown', (e) ->
				keyCode = e.keyCode || e.which;

				if keyCode == 9
					e.preventDefault();
					start = $(this).get(0).selectionStart;
					end = $(this).get(0).selectionEnd;

					# set textarea value to: text before caret + tab + text after caret
					$(this).val $(this).val().substring(0, start) + "\t" + $(this).val().substring(end);

					# put caret at right position again
					$(this).get(0).selectionStart =
					$(this).get(0).selectionEnd = start + 1;
			
			$saveButton.click () =>
				$saveButton.button 'saving'

				# need all values entered
				if $newsDate.val().length == 0 or $newsTitle.val().length == 0 or $newsPost.val().length == 0 or $('#editNewsForm .error', $popup).length > 0
					$validationAlert.slideDown 'fast'
					$saveButton.button 'reset'
					return
				
				$validationAlert.slideUp 'fast'
				
				post =
					_id: newsItem?._id
					year: @curYear
					date: moment($newsDate.val(), dateFormat).toDate()
					title: $newsTitle.val()
					content: $newsPost.val()
				
				$.ajax
					url: '/admin/saveNews'
					type: 'POST'
					data: post
					dataType: 'json'
					success: (reply) =>
						if !reply.success
							alert "Error saving news:\n#{reply.error}"
							$saveButton.button 'reset'
						else
							$saveButton.button 'saved'
							@loadData(@curYear)
							
							setTimeout((-> $popup.modal 'hide'), 1000)
					error: (req, status, errMsg) =>
						alert "Error saving news: #{status}\n#{errMsg}"
						$saveButton.button 'reset'

			$popup.modal()
		
		if @newsFormHtml?
			openPopup()
		else
			$.ajax
				url: '/static/admin/tabs/news-form.html'
				success: (content) =>
					@newsFormHtml = content
					openPopup()
				error: (req, status, errMsg) ->
					alert "Error loading modal view: #{status}\n#{errMsg}"
	
	delNewsPostClick: (newsItem) -> () =>
		openPopup = () =>
			$popup = $(@newsDelConfHtml)
			$delButton = $('#delButton', $popup)
			
			$title = $('#title', $popup)
			$title.text(newsItem.title)
			
			$preview = $('#preview', $popup)
			$preview.html(newsItem.html)

			$delButton.click () =>
				$delButton.button 'deleting'
				
				post =
					_id: newsItem?._id
				
				$.ajax
					url: '/admin/deleteNews'
					type: 'POST'
					data: post
					dataType: 'json'
					success: (reply) =>
						if !reply.success
							alert "Error removing news:\n#{reply.error}"
							$delButton.button 'reset'
						else
							$delButton.button 'deleted'
							@loadData(@curYear)
							
							setTimeout((-> $popup.modal 'hide'), 1000)
					error: (req, status, errMsg) =>
						alert "Error removing news: #{status}\n#{errMsg}"
						$delButton.button 'reset'

			$popup.modal()

		if @newsDelConfHtml?
			openPopup()
		else
			$.ajax
				url: '/static/admin/tabs/news-delconf.html'
				success: (content) =>
					@newsDelConfHtml = content
					openPopup()
				error: (req, status, errMsg) ->
					alert "Error loading modal view: #{status}\n#{errMsg}"
	
	loadData: (year) ->
		super
		
		if not @viewLoaded
			return
		
		$.ajax
			url: "/admin/getNews?year=#{year}"
			cache: false
			success: (news) =>
				@$newsTable.empty()
				
				for newsItem in news
					$newsRow = $ '<tr>'
					$newsRow.append $('<td>').text moment(newsItem.date).format dateFormat
					$newsRow.append $('<td>').text newsItem.title
					$newsRow.append $('<td>').html newsItem.html
					$newsRow.append $('<td>').append $('<div>').addClass('btn-group')
						.append($editButton = $('<button>').addClass('btn btn-primary').attr('type', 'button').text('Edit'))
						.append($delButton = $('<button>').addClass('btn btn-danger').attr('type', 'button').text('Delete'))
					
					$delButton.button()
					$delButton.attr
						'data-loading-text': 'Deleting...'
						'data-complete-text': 'Deleted'
						autocomplete: 'off'
					
					@$newsTable.append $newsRow
					
					$editButton.click @editNewsPostClick newsItem
					$delButton.click @delNewsPostClick newsItem
			error: (req, status, errMsg) ->
				alert "Error loading news: #{status}\n#{errMsg}"
