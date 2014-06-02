
var http = require('http');
var fs = require('fs');
var central = require('./ble-central');
var events = require('events');

var attitudeEmitter = new events.EventEmitter();
central(updatedAttitude);
startHTTPServer();

function startHTTPServer() {
  var server = http.createServer(handleHTTPRequest);
  var socket = require('socket.io')(server);
  server.listen(2000);
  initWebsocket(socket);
}

function handleHTTPRequest(req, res) {
  console.log(req.url);
  if (req.url === '/') {
    handleIndexRequest(req, res);
    return;
  }
  if (req.url === '/socket.io.js') {
    handleScriptRequest('socket.io-1.0.3.js', req, res);
    return;
  }
  if (req.url === '/three.js') {
    handleScriptRequest('three.min.js', req, res);
    return;
  }
}

function handleIndexRequest(req, res) {
  res.writeHead(200, {'Content-Type': 'text/html'});
  var fileStream = fs.createReadStream(__dirname + '/client/index.html');
  fileStream.pipe(res);
}

function handleScriptRequest(fileName, req, res) {
  res.writeHead(200, {'Content-Type': 'application/javascript'});
  var fileStream = fs.createReadStream(__dirname + '/client/' + fileName);
  fileStream.pipe(res);
}

function initWebsocket(socket) {
  socket.on('connection', function(client) {
    console.log('connected');
    attitudeEmitter.on('data', function(data) {
      client.emit('attitude', data);
    })
  });
}

function updatedAttitude(err, attitude) {
  attitudeEmitter.emit('data', attitude);
}
