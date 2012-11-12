curYear = null
curTab = '#competition'

$ () ->
	$("#spinner}").bind "ajaxSend", () -> $(this).show()
	$("#spinner}").bind "ajaxStop", () -> $(this).hide()
	$("#spinner}").bind "ajaxError", () -> $(this).hide()
		
	$('#navbar a[data-toggle="tab"]').on 'shown', (e) ->
		changeTab $(e.target).attr 'href'
		# e.relatedTarget = old tab
	
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
		when "#competition"
			$.ajax(
				url: "/admin/getCompetition?year=#{curYear}"
				cache: false
			).done (comp) ->
				$('#regBegin').val new Date comp.registrationBegin
				$('#regEnd').val new Date comp.registrationEnd
				$('#voteBegin').val new Date comp.votingBegin
				$('#voteEnd').val new Date comp.votingEnd
				$('#devBegin').val new Date comp.devBegin
				$('#devEnd').val new Date comp.devEnd
				$('#entryCutoff').val new Date comp.entryCutoff
				$('#privRelease').val new Date comp.privateRelease
				$('#pubRelease').val new Date comp.publicRelease
				$('#rules').val comp.rules

saveData = () ->
	# save
