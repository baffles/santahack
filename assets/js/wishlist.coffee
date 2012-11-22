$ () ->
	$('#joinButton').click (e) ->
		$(this).button 'joining'
	
	$('#joinForm').submit (e) ->
		#e.preventDefault()
	
	$mainWithdrawButton = $('#withdrawButton')
	$mainWithdrawButton.click (e) ->
		# add a confirmation that bypasses the default and posts the answer (use a content modal thingy)
		$(this).button 'withdrawing'
	
	$('#withdrawForm').submit (e) ->
		e.preventDefault()
		
		$.ajax
			url: 'withdraw-popup'
			success: (content) =>
				$popup = $(content)
				
				$('#withdrawButton', $popup).click (e) ->
					$(this).button 'withdrawing'
				
				$popup.on 'hidden', () ->
					$mainWithdrawButton.button 'reset'
				
				$popup.modal()
			error: (req, status, errMsg) ->
				alert "Error loading modal view: #{status}\n#{errMsg}"
