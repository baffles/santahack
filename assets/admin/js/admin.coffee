dateFormat = 'M/D/YY h:mm A'

class Tab
	constructor: (@viewUrl, @onViewLoaded) ->
		@$container = null
		@curYear = null
		@viewLoaded = false
	
	loadData: (@curYear) ->
	
	loadView: () ->
		if not @viewLoaded
			$.ajax
				url: @viewUrl
				success: (content) =>
					@$container.html content
					@viewLoaded = true
					@onViewLoaded @$container if @onViewLoaded?
				error: (req, status, errMsg) ->
					alert "Error loading tab view: #{status}\n#{errMsg}"
	
	setContainer: (@$container) ->

Admin = new class
	constructor: () ->
		@curYear = null
		@curTab = null
		
		@$tabContent = null
		@$navBar = null
		@tabs = {}
		
		$ () =>
			$("#spinner").bind "ajaxSend", () -> $(this).show()
			$("#spinner").bind "ajaxStop", () -> $(this).hide()
			$("#spinner").bind "ajaxError", () -> $(this).hide()
			
			@$tabContent = $ $('.tab-content')[0]
			@$navBar = $ $('#navbar')[0]
			
			@loadCompetitions()
	
	addTab: (name, displayName, tab) ->
		$tabPane = $('<div>').addClass('tab-pane').attr('id', name)
		$container = $('<div>').addClass('container')
		$tabPane.append $container
		@$tabContent.append $tabPane
		
		$navEntry = $('<li>').append($tabNav = $('<a>').text(displayName).attr
			href: "##{name}"
			'data-toggle': 'tab'
		)
		@$navBar.append $navEntry
		
		$tabNav.on 'shown', (e) =>
			@showTab @tabs[$(e.target).attr('href').substr(1)]
			# e.relatedTarget = old tab
		
		@tabs[name] =
			tab: tab
			$tabNav: $tabNav
			$tabPane: $tabPane
		
		tab.setContainer $container
	
	selectTab: (name) ->
		@tabs[name].$tabNav.tab 'show'
		
	selectYear: (year) ->
		@curYear = year
		$('#compoDropdownLabel').text year
		@curTab?.tab.loadData(@curYear)
	
	showTab: (tab) ->
		@curTab = tab
		@curTab.tab.loadView()
		@curTab.tab.loadData(@curYear) if @curYear?
	
	loadCompetitions: () ->
		# load the list of competitions, then load the most current competition
		$('#compoDropdownLabel').text 'Loading...'
		$compoMenu = $('#compoDropdownMenu')
		$compoMenu.empty()
		$.ajax
			url: '/admin/getCompetitionList'
			cache: false
			success: (years) =>
				for year in years
					$compoMenu.append $('<li>').append($a = $('<a>').text(year).attr
						href: '#'
						tabindex: -1
					)
					
					((year) => $a.click (e) =>
						e.preventDefault()
						@selectYear year
					)(year)
				
				@selectYear years[0]
			error: (req, status, errMsg) ->
				alert "Error loading competition list: #{status}\n#{errMsg}"
	

# need to monitor for edits to set dirty to prompt for save
# need to ask about save before changing competitions
