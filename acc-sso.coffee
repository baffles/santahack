lib =
	https: require 'https'
	xml2js: require 'xml2js'

module.exports = class AccSso
	constructor: () ->
	
	getLoginUrl: (returnUrl) ->
		"http://www.allegro.cc/account/login/#{returnUrl.replace('?', '$')}"
	
	processAuthenticationToken: (token, callback) ->
		throw 'callback required' if not callback?
		if token?
			lib.https.get "https://www.allegro.cc/account/authenticate-token/#{token}", (response) ->
				resBody = ''

				response.on 'data', (chunk) ->
					resBody += chunk

				response.on 'end', () ->
					parser = new lib.xml2js.Parser()
					parser.addListener 'end', (loginInfo) ->
						if loginInfo.response.$.valid is 'true'
							user =
								id: loginInfo.response.member[0].$.id
								name: loginInfo.response.member[0].name[0]
								avatar: loginInfo.response.member[0].avatar[0]._
								picture: loginInfo.response.member[0].picture[0]._

							callback null, user
						else
							callback 'invalid allegro.cc authentication token', null

					parser.parseString resBody
				
				response.on 'error', (error) -> callback error, null
		else
			callback 'token is null', null
