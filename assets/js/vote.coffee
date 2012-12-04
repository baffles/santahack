$ () ->
	$('input[type=radio]').tooltip
		placement: 'bottom'
	
	$('.status-column').show()
	
	$('.status-column i').tooltip
		placement: 'bottom'
		title: 'Saved'
	
	$('input[type=radio]').change () ->
		if $(this).is(':checked')
			id = this.name
			
			vote = { }
			vote[id] = parseInt this.value
			
			$statusIcon = $("#icon_#{id}")
			$row = $statusIcon.parents('tr')
			
			$.ajax
				url: 'vote?json'
				type: 'POST'
				data: vote
				dataType: 'json'
				beforeSend: (req, settings) ->
					$statusIcon.removeClass().addClass('icon-refresh')
					$statusIcon.data('tooltip').options.title = 'Saving...'
					$row.removeClass('error')
				success: (reply) ->
					if !reply.success
						$statusIcon.removeClass().addClass('icon-remove')
						$statusIcon.data('tooltip').options.title = "Error saving vote: #{reply.error}"
						$row.removeClass().addClass('error')
					else
						$statusIcon.removeClass().addClass('icon-ok')
						$statusIcon.data('tooltip').options.title = 'Saved'
						$row.removeClass('error')
				error: (req, status, errMsg) ->
					$statusIcon.removeClass().addClass('icon-remove')
					$statusIcon.data('tooltip').options.title = "Error saving vote: #{errMsg}"
					$row.removeClass().addClass('error')
	
	$('#manualButtons').hide()