_ = require('underscore')._
hungarian = require('./hungarian')

###
in: [ { sourceUser: 1, destUser: 2, wishlistScore: 2 },
  { sourceUser: 1, destUser: 3, wishlistScore: 5 },
  { sourceUser: 2, destUser: 1, wishlistScore: 3 },
  { sourceUser: 2, destUser: 3, wishlistScore: 4 },
  { sourceUser: 3, destUser: 1, wishlistScore: 4 },
  { sourceUser: 3, destUser: 2, wishlistScore: 1 } ]

prefOS = {}
prefOS[1] = 'windows'
prefOS[2] = 'windows'
prefOS[3] = 'windows'
prefOS[4] = 'windows'

canDev = {}
canDev[1] = { windows: true, linux: true, osx: true }
canDev[2] = { windows: true, linux: true, osx: true }
canDev[3] = { windows: true, linux: true, osx: true }
canDev[4] = { windows: true, linux: true, osx: true }

results = module.exports.optimizePairings votes, canDev, prefOS

out: [ { sourceUser: 1, destUser: 2, wishlistScore: 2 },
  { sourceUser: 2, destUser: 3, wishlistScore: 4 },
  { sourceUser: 3, destUser: 1, wishlistScore: 4 } ]
###

module.exports =
	optimizePairings: (votes, canDev, prefOS) -> # [ { sourceUser:, destUser:, wishlistScore: } ]
		matrix = []
		id = 0
		userMap = []
		userUnmap = []
		for user in _.uniq _.pluck(votes, 'sourceUser').concat(_.pluck(votes, 'destUser'))
			userMap[user] = id
			userUnmap[id] = user
			id++
		size = id
		
		for sourceUser, votes of _.groupBy votes, 'sourceUser'
			row = []
			row[i] = -440 for i in [0..size-1] # default of -500 if user didn't vote
			row[userMap[vote.destUser]] = Math.round(vote.wishlistScore * 10) for vote in votes
			for vote in votes
				if not canDev[sourceUser][prefOS[vote.destUser]]
					row[userMap[vote.destUser]] -= 690 # cost of 750 if canDev doesn't match
			row[userMap[sourceUser]] = -940 # user should never get assigned themselves
			matrix[userMap[sourceUser]] = row
		
		cMatrix = hungarian.makeCostMatrix matrix, (val) -> 60 - val # best vote is 5, so that gets a cost of 10. ends up 1000 for self-assignment, and 500 for anything user didn't vote on
		
		results = new hungarian().compute cMatrix
		assignments = []
		
		for res in results
			throw 'Person assigned to self' if res.x == res.y
			source = userUnmap[res.y]
			dest = userUnmap[res.x]
			assignments.push { sourceUser: source, destUser: dest, wishlistScore: matrix[res.y][res.x] }
		
		assignments

