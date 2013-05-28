# User management tasks (login/out)

lib =
	accSso: require '../lib/acc-sso'

accSso = new lib.accSso

module.exports =
	register: (app, data) ->
		app.get '/login', (req, res) ->
			returnUrl = req.query.return
			accReturn = process.env.ACCRETURN ? "http://#{req.host}/login-return"
			accReturn += "$return=#{returnUrl}" if returnUrl?
			res.redirect accSso.getLoginUrl accReturn

		app.get '/logout', (req, res) ->
			req.session.user = null
			res.redirect (req.query.return) ? '/'

		app.get '/login-return', (req, res, next) ->
			req.session.user = null

			await
				accSso.processAuthenticationToken req.query.token, defer accErr, accUser
			if accErr
				next accErr
				return

			data.updateUserData accUser

			await
				data.getUserData accUser.id, defer dbErr, userData
			if dbErr?
				next dbErr
				return

			# generate user information for cookie; any data from acc overrides whatever was in DB (update may not have happened yet)
			userData = userData
			for k, v of accUser
				userData[k] = v
			
			delete userData._id # no need to store the db ID in the session
			req.session.user = userData
			res.redirect req.query.return ? '/'