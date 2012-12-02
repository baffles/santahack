$ () ->
	$('#joinForm button[name="join"]').click (e) ->
		$(this).button 'joining'
	
	$mainWithdrawButton = $('#withdrawForm button[name="withdraw"]')
	$mainWithdrawButton.click (e) ->
		$(this).button 'withdrawing'
	
	$('#withdrawForm').submit (e) ->
		e.preventDefault()
		
		$.ajax
			url: '/static/html/withdraw-popup.html'
			success: (content) =>
				$popup = $(content)
				
				$('#withdrawButton', $popup).click (e) ->
					$(this).button 'withdrawing'
				
				$popup.on 'hidden', () ->
					$mainWithdrawButton.button 'reset'
				
				$popup.modal()
			error: (req, status, errMsg) ->
				alert "Error loading modal view: #{status}\n#{errMsg}"
	
	$saveButton = $('#wishlistForm button[name="save"]')
	$saveButton.enable = () -> @button 'reset'
	$saveButton.disable = () -> @attr 'disabled', 'disabled'
	$saveButton.saved = () ->
		@button 'saved'
		# setTimeout, because calling button() does the same, otherwise our disable gets squashed
		setTimeout (=> @attr 'disabled', 'disabled'), 1
	$saveButton.saving = () ->
		@button 'saving'
		setTimeout (=> @attr 'disabled', 'disabled'), 1
		
	$discardButton = $('<button>').addClass('btn').attr('name', 'discard').attr('data-discarding-text', 'Discarding...').text('Discard changes')
	$discardButton.button()
	$discardButton.enable = () -> @button 'reset'
	$discardButton.disable = () ->
		@button 'reset'
		# setTimeout, because calling button() does the same, otherwise our disable gets squashed
		setTimeout (=> @attr 'disabled', 'disabled'), 1
	$discardButton.discarding = () ->
		@button 'discarding'
		setTimeout (=> @attr 'disabled', 'disabled'), 1

	$('#wishlistButtons').append $discardButton
	
	$saveButton.click (e) ->
		$saveButton.saving()
	
	$wishlistForm = $('#wishlistForm')
	
	$wishlistForm.submit (e) ->
		e.preventDefault()
		$saveButton.saving()
		$discardButton.disable()
		
		$.ajax
			url: 'wishlist'
			type: 'POST'
			data:
				wish1: $('#wishlistForm input[name="wish1"]').val()
				wish2: $('#wishlistForm input[name="wish2"]').val()
				wish3: $('#wishlistForm input[name="wish3"]').val()
				machinePerformance: $('#wishlistForm select[name="machinePerformance"]').val()
				preferredOS: $('#wishlistForm select[name="preferredOS"]').val()
				canDevWindows: if $('#wishlistForm input[name="canDevWindows"]').is(':checked') then true else undefined
				canDevLinux: if $('#wishlistForm input[name="canDevLinux"]').is(':checked') then true else undefined
				canDevMac: if $('#wishlistForm input[name="canDevMac"]').is(':checked') then true else undefined
				json: true #! better way to detect ajax?
			dataType: 'json'
			success: (content) =>
				if content.success
					$saveButton.saved()
					$discardButton.disable()
				else
					alert "Error saving wishlist: #{content.error}"
			error: (req, status, errMsg) ->
				alert "Error saving wishlist: #{status}\n#{errMsg}"
				$saveButton.enable()
				$discardButton.enable()
	
	$discardButton.click (e) ->
		e.preventDefault()
		$saveButton.disable()
		$discardButton.discarding()
		
		$.ajax
			url: 'wishlist.json'
			success: (wishlist) ->
				$('#wishlistForm input[name="wish1"]').val(wishlist.wish1)
				$('#wishlistForm input[name="wish2"]').val(wishlist.wish2)
				$('#wishlistForm input[name="wish3"]').val(wishlist.wish3)
				$('#wishlistForm select[name="machinePerformance"]').val(wishlist.machinePerformance)
				$('#wishlistForm select[name="preferredOS"]').val(wishlist.preferredOS)
				$('#wishlistForm input[name="canDevWindows"]').attr('checked', wishlist.canDevWindows)
				$('#wishlistForm input[name="canDevLinux"]').attr('checked', wishlist.canDevLinux)
				$('#wishlistForm input[name="canDevMac"]').attr('checked', wishlist.canDevMac)
				$saveButton.saved()
				$discardButton.disable()
			error: (req, status, errMsg) ->
				alert "Error loading original wishlist: #{status}\n#{errMsg}"
				$saveButton.enable()
				$discardButton.enable()
	
	$wishlistForm.on 'keyup keypress blur change', () ->
		# on form change, re-enable the save/discard buttons
		$saveButton.enable()
		$discardButton.enable()
	
	$saveButton.saved()
	$discardButton.disable()
