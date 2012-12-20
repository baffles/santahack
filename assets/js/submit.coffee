$ () ->
	$ssLabel = $ '#screenshotsLabel'
	$ssLabel.append '(s) ['
	$ssLabel.append $addSSLink = $('<a>').attr('href', '#').attr('title', 'Add more upload slots').text('+')
	$ssLabel.append ']'
	
	$ssFiles = $ '#screenshots'
	
	$addSSLink.click (e) ->
		e.preventDefault()
		$ssFiles.append $('<input>').attr('type', 'file').attr('name', 'screenshot[]')
	
	$('#saveButton').click (e) ->
		$(this).button 'uploading'
	
	$('#name').bind 'textchange', () ->
		if $(this).val().length > 0
			$(this).parents('.control-group').removeClass 'warning'
		else
			$(this).parents('.control-group').addClass 'warning'
	
	$('#description').bind 'textchange', () ->
		if $(this).val().length > 0
			$(this).parents('.control-group').removeClass 'warning'
		else
			$(this).parents('.control-group').addClass 'warning'
	
	$('#wishesImplemented input[type=checkbox]').change () ->
		if $('input[type=checkbox]', $(this).parents('.controls')).is(':checked')
			$(this).parents('.control-group').removeClass 'warning'
		else
			$(this).parents('.control-group').addClass 'warning'
	
	$('#sourcePack').change () ->
		if $(this).val().length > 0
			$(this).parents('.control-group').removeClass 'warning'
		else
			$(this).parents('.control-group').addClass 'warning'
	
	###$('.lightbox').lightbox
		fitToScreen: true
		loopImages: true
		fileLoadingImage: '/static/lib/lightbox/images/loading.gif'
		fileBottomNavCloseImage: '/static/lib/lightbox/images/closelabel.gif'
		displayDownloadLink: true###
