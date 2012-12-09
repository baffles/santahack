class RunPairingTab extends Tab
	constructor: () ->
		super '/static/admin/tabs/run-pairing.html', (container) =>
			$('#runPairing', @$container).click () => @runPairing()
	
	runPairing: () ->
		$.ajax
			url: "/admin/runPairing?year=#{@curYear}"
			type: 'POST'
			data: { }
			dataType: 'json'
			beforeSend: () ->
				$('#results', @$container).slideUp 'fast'
			success: (reply) =>
				if not reply?.success
					alert "Error running pairing:\n#{reply.error}"
				else
					$results = $('#results', @$container)
					$results.text reply.summary
					$results.slideDown 'fast'
			error: (req, status, errMsg) =>
				alert "Error running pairing: #{status}\n#{errMsg}"
