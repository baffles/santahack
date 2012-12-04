cluster = require 'cluster'
numWorkers = require('os').cpus().length

if cluster.isMaster
	console.log 'Hypervisor cluster'
	console.log "Starting #{numWorkers} workers running web.coffee"
	
	cluster.setupMaster
		exec: 'web.coffee'
	
	cluster.on 'online', (worker) ->
		console.log "Worker #{worker.id} online, pid #{worker.process.pid}"
	
	cluster.on 'exit', (worker, code, signal) ->
		console.log "Worker #{worker.id} (#{worker.process.pid}) died. Respawning in 30 seconds..."
		setTimeout (() -> cluster.fork()), 30000
	
	# fork initial worker threads
	for i in [1..numWorkers]
		cluster.fork()
else
	throw 'Unexpected codepath'
