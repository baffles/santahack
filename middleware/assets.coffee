# Compile dynamic assets and cache them

lib = 
	express: require 'express'
	compiler: require 'connect-compiler'

module.exports =
	register: (app) ->
		app.use lib.compiler
			enabled: [ 'coffee', 'stylus', 'uglify', 'jade' ]
			src: '../assets'
			dest: '../assets/compiled'
			mount: '/static'
			options:
				stylus: { compress: true }
				jade: { pretty: false }
		app.use lib.compiler
			enabled: [ 'uglify' ]
			src: [ '../assets', '../assets/compiled' ]
			dest: '../assets/compiled'
			mount: '/static'
		app.use '/static', lib.express.static "#{__dirname}/../public"
		app.use '/static', lib.express.static "#{__dirname}/../assets/compiled"