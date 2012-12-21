# INCOMPLETE

option '-s', '--source [DIR]', 'directory containing asset source'
option '-o', '--output [DIR]', 'directory for compiled assets'

task 'build:assets', 'pre-compile all assets for production use', (options) ->
	fs = require 'fs'
	file = require 'file'
	wrench = require 'wrench'
	path = require 'path'
	coffee = require 'coffee-script'
	uglify = require 'uglify-js'
	jade = require 'jade'
	stylus = require 'stylus'
	
	assetsBase = options.source || "#{__dirname}/assets"
	compiledBase = options.output || "#{__dirname}/assets/compiled"
	
	if fs.existsSync compiledBase
		console.log "Removing pre-compiled assets in #{__dirname}/assets/compiled"
		console.log ''
		wrench.rmdirSyncRecursive "#{__dirname}/assets/compiled"
	
	console.log 'Pre-compiling all assets for production use...'
	console.log "Source: #{assetsBase}"
	console.log "Output: #{compiledBase}"
	console.log ''
	
	file.walkSync assetsBase, (dir, dirs, files) ->
		if compiledBase != dir.substr 0, compiledBase.length
			# no infinite looping on compiled assets!
			subdir = file.path.relativePath assetsBase, dir
			destDir = path.join compiledBase, subdir
			
			file.mkdirsSync destDir
			
			for fn in files
				contents = fs.readFileSync path.join(dir, fn), 'utf8'
				compiled = ''
				
				###write: (dest, data, cb) ->
				        if @info.log_level <= LOG.INFO
				            _dest = dest
				            {src, cwd} = @info
				            cwd += '/' unless cwd[cwd.length-1] is '/'
				            if src.indexOf(cwd) is 0
				                src .= slice cwd.length
				            if _dest.indexOf(cwd) is 0
				                _dest .= slice cwd.length
				            prefix = commonPath src, _dest
				            if prefix[0] is '/'
				                prefix .= slice 1
				            if len = prefix.length
				                @log LOG.INFO, "writing #prefix{ #{src.slice len} --> #{_dest.slice len} }"
				            else
				                @log LOG.INFO, "writing #src --> #_dest"
				        fs.writeFile dest, data, 'utf8', cb###
				
				switch path.extname fn
					when '.coffee'
						console.log "\tCoffee #{path.join subdir, fn}"
						destFile = path.join destDir, fn.replace /\.coffee$/, '.js'
						destMinFile = path.join destDir, fn.replace /\.coffee$/, '.min.js'
						
						compiled = coffee.compile contents, { bare: true, filename: "#{path.join subdir, fn}" }
						console.log "Write to #{destFile}"
						fs.writeFileSync destFile, compiled, 'utf8'
						
						ast = uglify.parser.parse compiled
						ast = uglify.uglify.ast_mangle ast
						ast = uglify.uglify.ast_squeeze ast
						compiled = uglify.uglify.gen_code ast
						
						console.log compiled
						
					when '.jade'
						console.log "\tJade #{path.join subdir, fn}"
					when '.styl'
						console.log "\tStylus #{path.join subdir, fn}"
					else
						console.log "\tSkipping unknown file #{path.join subdir, fn}"
				
				#console.log path.join destDir, fn
	