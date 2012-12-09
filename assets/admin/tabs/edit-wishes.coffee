class EditWishesTab extends Tab
	constructor: () ->
		@$wishesTable = null
		
		super '/static/admin/tabs/edit-wishes.html', (container) =>
			@$wishesTable = $('#wishesTBody:first', @$container)
			
			if @curYear?
				@loadData @curYear
	
	loadData: (year) ->
		super
		
		if not @viewLoaded
			return
		
		$.ajax
			url: "/admin/getWishes?year=#{year}"
			cache: false
			success: (wishes) =>
				@$wishesTable.empty()
				
				for wish_ in wishes
					do =>
						wish = wish_
						$wishRow = $ '<tr>'
						$wishRow.append $('<td>').append($textbox = $('<input>').addClass('input-xxlarge').attr('name', wish.id).val(wish.wishText))
						$wishRow.append $('<td>').text(if wish.isListComplete then '[complete]')
						$wishRow.append $('<td>').append($statusIcon = $('<i>'))
				
						$statusIcon.iconSaved = () -> $statusIcon.removeClass().addClass('icon-ok')
						$statusIcon.iconTyping = () -> $statusIcon.removeClass().addClass('icon-asterisk')
						$statusIcon.iconSaving = () -> $statusIcon.removeClass().addClass('icon-upload')
						$statusIcon.iconError = () -> $statusIcon.removeClass().addClass('icon-remove')
				
						$statusIcon.iconSaved()
					
						do ->
							timeout = null
							$textbox.bind 'textchange', () ->
								clearTimeout timeout
								$statusIcon.iconTyping()
								timeout = setTimeout (() ->
										wish.wishText = $textbox.val()
									
										wishPost = {}
										wishPost[wish.id] = wish.wishText
									
										$.ajax
											url: "/admin/saveWishes?year=#{year}"
											type: 'POST'
											data: wishPost
											dataType: 'json'
											beforeSend: () ->
												$statusIcon.iconSaving()
											success: (reply) =>
												if not reply?.success
													alert "Error saving wish:\n#{reply.error}"
													$statusIcon.iconError()
												else
													$statusIcon.iconSaved()
											error: (req, status, errMsg) =>
												alert "Error saving wish: #{status}\n#{errMsg}"
												$statusIcon.iconError()
									), 2000
				
						@$wishesTable.append $wishRow
			error: (req, status, errMsg) ->
				alert "Error loading wishes: #{status}\n#{errMsg}"
