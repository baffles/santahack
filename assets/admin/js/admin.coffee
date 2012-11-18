curYear = null
curTab = '#competition'

dateFormat = 'M/D/YY h:mm A'

class Tab
	constructor: () ->

Admin = new class
	constructor: () ->
$ () ->
	$("#spinner}").bind "ajaxSend", () -> $(this).show()
	$("#spinner}").bind "ajaxStop", () -> $(this).hide()
	$("#spinner}").bind "ajaxError", () -> $(this).hide() #! should we do something sensible here on failure? alert user?
		
	$('#navbar a[data-toggle="tab"]').on 'shown', (e) ->
		changeTab $(e.target).attr 'href'
		# e.relatedTarget = old tab
	
	# validation on datetime fields
	$('input[data-type="date"]').keyup () ->
		valid = moment($(this).val(), dateFormat)?.isValid()
		
		$($(this).parents('.control-group').get 0)
			.removeClass('warning error info success')
			.addClass if valid then 'success' else 'error'
		
		$($(this).siblings('.help-inline').get 0).text if valid then '' else "#{dateFormat} (e.g., #{new moment().format dateFormat})"
		
	
	# enable tab in rules textbox (for markdown)
	$(document).delegate '#rules', 'keydown', (e) ->
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
	
	$saveButton = $('#competitionForm button[name="save"]')
	$saveButton.button()
	$saveButton.attr
		'data-loading-text': 'Saving...'
		'data-complete-text': 'Saved'
	
	$saveButton.click (e) ->
		e.preventDefault()
		saveData()
	
	$('#competitionForm button[name="discard"]').click (e) ->
		e.preventDefault()
		loadData()
	
	$('input', $ '#competitionForm').keyup () ->
		$saveButton.button 'reset'
	
	$('textarea', $ '#competitionForm').keyup () ->
		$saveButton.button 'reset'
	
	loadCompetitions()

# need to monitor for edits to set dirty to prompt for save
# need to ask about save before changing competitions

loadCompetitions = () ->
	# load the list of competitions, then load the most current competition
	$('#compoDropdownLabel').text 'Loading...'
	$('#compoDropdownMenu').empty()
	$.ajax(
		url: '/admin/getCompetitionList'
		cache: false
	).done (years) ->
		$('#compoDropdownMenu').append("<li><a href=\"#\" tabindex=\"-1\" data-year=\"#{year}\">#{year}</a></li>") for year in years
		changeYear years[0]
		
		# hook the dropdown menu
		$('#compoDropdownMenu a').click (e) ->
			changeYear $(this).attr 'data-year'

changeTab = (tab) ->
	curTab = tab
	loadData()

changeYear = (year) ->
	curYear = year
	$('#compoDropdownLabel').text(year)
	loadData()

loadData = () ->
	# request and load curComp/curTab
	console.log "load #{curTab} for #{curYear}"
	switch curTab
		when '#competition'
			$.ajax
				url: "/admin/getCompetition?year=#{curYear}"
				cache: false
				success: (comp) ->
					$('#competitionForm #regBegin').val moment(comp.registrationBegin).format dateFormat
					$('#competitionForm #regEnd').val moment(comp.registrationEnd).format dateFormat
					$('#competitionForm #voteBegin').val moment(comp.votingBegin).format dateFormat
					$('#competitionForm #voteEnd').val moment(comp.votingEnd).format dateFormat
					$('#competitionForm #devBegin').val moment(comp.devBegin).format dateFormat
					$('#competitionForm #devEnd').val moment(comp.devEnd).format dateFormat
					$('#competitionForm #entryCutoff').val moment(comp.entryCutoff).format dateFormat
					$('#competitionForm #privRelease').val moment(comp.privateRelease).format dateFormat
					$('#competitionForm #pubRelease').val moment(comp.publicRelease).format dateFormat
					$('#competitionForm #rules').val comp.rules
				
					$('#competitionForm input[data-type="date"]').each () ->
						valid = moment($(this).val(), dateFormat)?.isValid()

						$($(this).parents('.control-group').get 0)
							.removeClass('warning error info success')
							.addClass if valid then 'success' else 'error'

						$($(this).siblings('.help-inline').get 0).text if valid then '' else "#{dateFormat} (e.g., #{moment().format dateFormat})"
					
					$('#competitionForm button[name="save"]').button 'complete'
				error: (req, status, errMsg) ->
					alert "Error loading competition: #{status}\n#{errMsg}"
		
		when '#news'
			newsEditClick = (newsItem) -> () ->
				$popup = $('<div>').addClass('modal hide fade').attr
					tabindex: '-1'
					role: 'dialog'
					'aria-labelledby': 'label'
					'aria-hidden': 'true'
				
				$popup.append $('<div>').addClass('modal-header')
					.append($('<button>').text('x').addClass('close').attr
						'data-dismiss': 'modal'
						'aria-hidden': 'true'
					)
					.append($('<h3>').attr('id', 'label').text if newsItem? then 'Edit News Post' else 'Add News Post')
				
				$popup.append $popupBody = $('<div>').addClass('modal-body').append($('#editNewsForm'))
				
				$popup.append $('<div>').addClass('modal-footer')
					.append($('<button>').text('Close').addClass('btn').attr
						'data-dismiss': 'modal'
						'aria-hidden': 'true'
					)
					.append($saveButton = $('<button>').text('Save').addClass('btn btn-primary')).attr(
						'data-loading-text': 'Saving...'
						'data-complete-text': 'Saved!'
						autocomplete: 'off'
					)
				
				$newsDate = $('#editNewsForm #newsDate', $popup)
				$newsTitle = $('#editNewsForm #newsTitle', $popup)
				$newsPost = $('#editNewsForm #newsPost', $popup)
				
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
				
				$popup.button()
				$saveButton.click () ->
					$saveButton.button 'loading'
					
					# need all values entered
					if $newsDate.val().length == 0 or $newsTitle.val().length == 0 or $newsPost.val().length == 0 or $('#editNewsForm .error', $popup).length > 0
						alert 'Please ensure valid values are entered for all fields'
						$saveButton.button 'reset'
						return
					
					alert 'SAVE'
					# close the popup and reload the news
					$saveButton.button 'complete'
					#$popup.modal 'hide'
					#loadData()
				
				$popup.modal()
			
			$.ajax
				url: "/admin/getNews?year=#{curYear}"
				cache: false
				success: (news) ->
					$newsTable = $ '#newsTBody'
					$newsTable.empty()
					
					for newsItem in news
						$newsRow = $ '<tr>'
						$newsRow.append $('<td>').text moment(newsItem.date).format dateFormat
						$newsRow.append $('<td>').text newsItem.title
						$newsRow.append $('<td>').html newsItem.html
						$newsRow.append $('<td>').append $editButton = $('<button>').addClass('btn').attr('type', 'button').text('Edit')
						
						$newsTable.append $newsRow
						
						$editButton.click newsEditClick newsItem
					
					$addRow = $('<tr>').append($('<td>')).append($('<td>')).append($('<td>')).append $('<td>').append $addButton = $('<button>').addClass('btn').attr('type', 'button').text('Add')
					$newsTable.append $addRow
					$addButton.click newsEditClick null
				error: (req, status, errMsg) ->
					alert "Error loading news: #{status}\n#{errMsg}"

saveData = () ->
	console.log "save #{curTab} for #{curYear}"
	switch curTab
		when '#competition'
			$saveButton = $('#competitionForm button[name="save"]')
			$saveButton.button 'loading'
			
			if $('#competitionForm .error').length > 0
				alert 'Please correct any errors'
				$saveButton.button 'reset'
				return
			
			competition =
				year: curYear
				registrationBegin: moment($('#competitionForm #regBegin').val(), dateFormat).toDate()
				registrationEnd: moment($('#competitionForm #regEnd').val(), dateFormat).toDate()
				votingBegin: moment($('#competitionForm #voteBegin').val(), dateFormat).toDate()
				votingEnd: moment($('#competitionForm #voteEnd').val(), dateFormat).toDate()
				devBegin: moment($('#competitionForm #devBegin').val(), dateFormat).toDate()
				devEnd: moment($('#competitionForm #devEnd').val(), dateFormat).toDate()
				entryCutoff: moment($('#competitionForm #entryCutoff').val(), dateFormat).toDate()
				privateRelease: moment($('#competitionForm #privRelease').val(), dateFormat).toDate()
				publicRelease: moment($('#competitionForm #pubRelease').val(), dateFormat).toDate()
				rules: $('#competitionForm #rules').val()
			
			$.ajax
				url: '/admin/saveCompetition'
				type: 'POST'
				data: competition
				dataType: 'json'
				success: (reply) ->
					if !reply.success
						alert "Error saving competition:\n#{reply.error}"
						$saveButton.button 'reset'
					else
						$saveButton.button 'complete'
				error: (req, status, errMsg) ->
					alert "Error saving competition: #{status}\n#{errMsg}"
					$saveButton.button 'reset'
		