var env = process.env.ENV || "local";

var express = require('express');

var app = express.createServer(express.logger());

app.get('/', function(request, response) {
	response.send('We will be back soon! [' + env + ']');
});

var port = process.env.PORT || 5000;
app.listen(port, function() {
	console.log("Listening on " + port);
});
