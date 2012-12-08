class EligibilityTab extends Tab
	constructor: () ->
		@$eligibilityTable = null
		
		super '/static/admin/tabs/eligibility.html', (container) =>
			@$eligibilityTable = $('#eligibilityTBody:first', @$container)
			
			#$('button', @$container).tooltip()
			
			$('#refreshButton', @$container).click () => @loadData @curYear
			$('#updateButton', @$container).click () => @runUpdate 'update'
			$('#clearButton', @$container).click () => @runUpdate 'clear'
			
			if @curYear?
				@loadData @curYear
	
	loadData: (year) ->
		super
		
		if not @viewLoaded
			return
		
		$.ajax
			url: "/admin/getEligibility?year=#{year}"
			cache: false
			success: (users) =>
				@$eligibilityTable.empty()
				
				for user in users
					$userRow = $('<tr>').addClass(if user.isEligible then 'success' else 'error')
					$userRow.append $('<td>').text(user.name)
					$userRow.append $('<td>').append $('<i>').addClass(if user.isEligible then 'icon-ok' else 'icon-remove')
					@$eligibilityTable.append $userRow
			error: (req, status, errMsg) ->
				alert "Error loading eligibility: #{status}\n#{errMsg}"
	
	runUpdate: (mode) ->
		$.ajax
			url: "/admin/updateEligibility?year=#{@curYear}"
			type: 'POST'
			data: { mode }
			dataType: 'json'
			success: (reply) =>
				if !reply.success
					alert "Error updating eligibility:\n#{reply.error}"
				else
					@loadData @curYear
			error: (req, status, errMsg) =>
				alert "Error updating eligibility:\n#{reply.error}"
