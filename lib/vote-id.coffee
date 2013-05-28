crypto = require 'crypto'

module.exports = class VoteID
	constructor: (@cipher, @key) ->
	
	toID: (voteItem) ->
		c = crypto.createCipher @cipher, @key
		id = JSON.stringify { destUser: voteItem.destUser, wish: voteItem.wish }
		return c.update(id, 'utf8', 'hex') + c.final('hex')
	
	fromID: (id) ->
		d = crypto.createDecipher @cipher, @key
		item = d.update(id, 'hex', 'utf8') + d.final('utf8')
		JSON.parse item