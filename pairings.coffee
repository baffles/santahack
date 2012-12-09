_ = require('underscore')._
hungarian = require('./hungarian')

###
in: [ { sourceUser: 1, destUser: 2, wishlistScore: 2 },
  { sourceUser: 1, destUser: 3, wishlistScore: 5 },
  { sourceUser: 2, destUser: 1, wishlistScore: 3 },
  { sourceUser: 2, destUser: 3, wishlistScore: 4 },
  { sourceUser: 3, destUser: 1, wishlistScore: 4 },
  { sourceUser: 3, destUser: 2, wishlistScore: 1 } ]

results = module.exports.optimizePairings votes

out: [ { sourceUser: 1, destUser: 2, wishlistScore: 2 },
  { sourceUser: 2, destUser: 3, wishlistScore: 4 },
  { sourceUser: 3, destUser: 1, wishlistScore: 4 } ]
###

module.exports =
	optimizePairings: (votes) -> # [ { sourceUser:, destUser:, wishlistScore: } ]
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
			row[userMap[vote.destUser]] = vote.wishlistScore * 10 | 0 for vote in votes
			(row[i] = -440 if not row[i]?) for i in [0..size-1]
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

