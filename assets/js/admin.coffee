curYear = null
curTab = '#competition'

dateFormat = 'M/D/YY h:mm A'

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
	
	$('#competitionForm button[name="save"]').click (e) ->
		e.preventDefault()
		saveData()
	
	$('#competitionForm button[name="discard"]').click (e) ->
		e.preventDefault()
		loadData()
		
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
					console.log comp
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
				error: (req, status, errMsg) ->
					alert "Error loading competition: #{status}\n#{errMsg}"
		
		when '#news'
			$.ajax
				url: "/admin/getNews?year=#{curYear}"
				cache: false
				success: (news) ->
					console.log news
					for newsItem in news
						$('#newsTBody').append("<tr><td>#{newsItem.date}</td><td>#{newsItem.title}</td><td>#{newsItem.content}</td></tr>")
				error: (req, status, errMsg) ->
					alert "Error loading news: #{status}\n#{errMsg}"

saveData = () ->
	console.log "save #{curTab} for #{curYear}"
	switch curTab
		when '#competition'
			if $('#competitionForm .error').length > 0
				alert 'Please correct any errors'
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
				error: (req, status, errMsg) ->
					alert "Error saving competition: #{status}\n#{errMsg}"
		