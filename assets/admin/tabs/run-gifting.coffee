class RunGiftingTab extends Tab
	constructor: () ->
		super '/static/admin/tabs/run-gifting.html', (container) =>
			$('#runGifting', @$container).click () => @runGifting()
	
	runGifting: () ->
		$.ajax
			url: "/admin/runGifting?year=#{@curYear}"
			type: 'POST'
			data: { }
			dataType: 'json'
			beforeSend: () ->
				$('#results', @$container).slideUp 'fast'
			success: (reply) =>
				if not reply?.success
					alert "Error running gifting:\n#{reply.error}"
				else
					$results = $('#results', @$container)
					$results.text reply.summary
					$results.slideDown 'fast'
			error: (req, status, errMsg) =>
				alert "Error running gifting: #{status}\n#{errMsg}"
