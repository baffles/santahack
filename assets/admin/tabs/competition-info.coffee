class CompetitionInfoTab extends Tab
	constructor: () ->
		@$regBegin = null
		@$regEnd = null
		@$voteBegin = null
		@$voteEnd = null
		@$devBegin = null
		@$devEnd = null
		@$entryCutoff = null
		@$privRelease = null
		@$pubRelease = null
		@$rules = null
		@$saveButton = null
		@$discardButton = null
		@$validationAlert = null
		
		super '/static/admin/tabs/competition-info.html', (container) =>
			@$regBegin = $('#competitionForm #regBegin:first', @$container)
			@$regEnd = $('#competitionForm #regEnd:first', @$container)
			@$voteBegin = $('#competitionForm #voteBegin:first', @$container)
			@$voteEnd = $('#competitionForm #voteEnd:first', @$container)
			@$devBegin = $('#competitionForm #devBegin:first', @$container)
			@$devEnd = $('#competitionForm #devEnd:first', @$container)
			@$entryCutoff = $('#competitionForm #entryCutoff:first', @$container)
			@$privRelease = $('#competitionForm #privRelease:first', @$container)
			@$pubRelease = $('#competitionForm #pubRelease:first', @$container)
			@$rules = $('#competitionForm #rules:first', @$container)
			@$saveButton = $('#competitionForm button[name="save"]:first', @$container)
			@$discardButton = $('#competitionForm button[name="discard"]:first', @$container)
			@$validationAlert = $('#validationAlert', @$container)
			
			$('button.close', @$validationAlert).click () =>
				@$validationAlert.slideUp 'fast'
			
			# validation on datetime fields
			$('input[data-type="date"]', @$container).keyup () ->
				valid = moment($(this).val(), dateFormat)?.isValid()

				$($(this).parents('.control-group').get 0)
					.removeClass('warning error info success')
					.addClass if valid then 'success' else 'error'

				$($(this).siblings('.help-inline').get 0).text if valid then '' else "#{dateFormat} (e.g., #{new moment().format dateFormat})"


			# enable tab in rules textbox (for markdown)
			$(document).delegate '#competitionForm #rules', 'keydown', (e) ->
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
			
			@$saveButton.click (e) =>
				e.preventDefault()
				@saveData()

			@$discardButton.click (e) =>
				e.preventDefault()
				@loadData @curYear

			$('#competitionForm input', @$container).keyup () =>
				@$saveButton.button 'reset'

			$('#competitionForm textarea', @$container).keyup () =>
				@$saveButton.button 'reset'
	
	loadData: (year) ->
		super
		
		$.ajax
			url: "/admin/getCompetition?year=#{year}"
			cache: false
			success: (comp) =>
				if comp?
					@$regBegin.val moment(comp.registrationBegin).format dateFormat
					@$regEnd.val moment(comp.registrationEnd).format dateFormat
					@$voteBegin.val moment(comp.votingBegin).format dateFormat
					@$voteEnd.val moment(comp.votingEnd).format dateFormat
					@$devBegin.val moment(comp.devBegin).format dateFormat
					@$devEnd.val moment(comp.devEnd).format dateFormat
					@$entryCutoff.val moment(comp.entryCutoff).format dateFormat
					@$privRelease.val moment(comp.privateRelease).format dateFormat
					@$pubRelease.val moment(comp.publicRelease).format dateFormat
					@$rules.val comp.rules
				else
					@$regBegin.val ''
					@$regEnd.val ''
					@$voteBegin.val ''
					@$voteEnd.val ''
					@$devBegin.val ''
					@$devEnd.val ''
					@$entryCutoff.val ''
					@$privRelease.val ''
					@$pubRelease.val ''
					@$rules.val ''
				
				# run validation on received data
				$('input[data-type="date"]', @$container).each () ->
					valid = moment($(this).val(), dateFormat)?.isValid()

					$($(this).parents('.control-group').get 0)
						.removeClass('warning error info success')
						.addClass if valid then 'success' else 'error'

					$($(this).siblings('.help-inline').get 0).text if valid then '' else "#{dateFormat} (e.g., #{moment().format dateFormat})"
				
				@$saveButton.button 'saved'
			error: (req, status, errMsg) ->
				alert "Error loading competition: #{status}\n#{errMsg}"
	
	saveData: () ->
		@$saveButton.button 'saving'
		
		if $('#competitionForm .error').length > 0
			@$validationAlert.slideDown 'fast'
			$("html, body").animate { scrollTop: 0 }, "fast";
			@$saveButton.button 'reset'
			return
		
		@$validationAlert.slideUp 'fast'
		
		competition =
			year: @curYear
			registrationBegin: moment(@$regBegin.val(), dateFormat).toDate()
			registrationEnd: moment(@$regEnd.val(), dateFormat).toDate()
			votingBegin: moment(@$voteBegin.val(), dateFormat).toDate()
			votingEnd: moment(@$voteEnd.val(), dateFormat).toDate()
			devBegin: moment(@$devBegin.val(), dateFormat).toDate()
			devEnd: moment(@$devEnd.val(), dateFormat).toDate()
			entryCutoff: moment(@$entryCutoff.val(), dateFormat).toDate()
			privateRelease: moment(@$privRelease.val(), dateFormat).toDate()
			publicRelease: moment(@$pubRelease.val(), dateFormat).toDate()
			rules: @$rules.val()
		
		$.ajax
			url: '/admin/saveCompetition'
			type: 'POST'
			data: competition
			dataType: 'json'
			success: (reply) =>
				if !reply.success
					alert "Error saving competition:\n#{reply.error}"
					@$saveButton.button 'reset'
				else
					@$saveButton.button 'saved'
			error: (req, status, errMsg) =>
				alert "Error saving competition: #{status}\n#{errMsg}"
				@$saveButton.button 'reset'
	