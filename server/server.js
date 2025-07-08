require('dotenv').config();
const fs = require('fs');
const path = require('path');
const https = require('https');
const WebSocket = require('ws');
const net = require('net');
const http = require('http'); // Only needed if you want to keep the non-secure HTTP endpoint

const certPath = path.join(__dirname, 'certs');
const key = fs.readFileSync(path.join(certPath, 'server.key'));
const cert = fs.readFileSync(path.join(certPath, 'server.crt'));

const WS_PORT = process.env.WS_PORT || 8443; // Use 8443 for secure WebSocket
const TCP_PORT = process.env.TCP_PORT || 9000;
const HTTP_PORT = 5000;

// --- Secure HTTPS & WebSocket server ---
const httpsServer = https.createServer({ key, cert });

const wss = new WebSocket.Server({ server: httpsServer });
const tcpClients = new Set();

httpsServer.listen(WS_PORT, () => {
  console.log(`HTTPS & WSS server running on https://localhost:${WS_PORT}`);
});

// Broadcast to all WebSocket clients
function broadcastWS(data) {
  const json = JSON.stringify(data);
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(json);
    }
  });
}

// Send to all TCP clients (as ASCII)
function broadcastTCP(data) {
  const json = JSON.stringify(data) + "\n";
  tcpClients.forEach(socket => {
    socket.write(json, 'ascii');
  });
}

// WebSocket server
wss.on('connection', ws => {
  console.log('WebSocket client connected');

  ws.on('message', message => {
    console.log('WS Received:', message);
    // Broadcast received WS message to TCP clients
    let data;
    try {
      data = JSON.parse(message);
      broadcastTCP(data);
    } catch (e) {
      console.error('Invalid JSON from WS:', e);
    }
  });

  ws.on('close', () => {
    console.log('WebSocket client disconnected');
  });
});

// TCP server for MT5 EA connection (not secure, for secure use tls module)
const tcpServer = net.createServer(socket => {    
  console.log('TCP client connected');
  tcpClients.add(socket);

  // Send a test trade immediately when a new TCP client connects (as ASCII)
  const testTrade = {
    cmd: "BUY",
    symbol: "EURUSD",
    lot: 0.1,
    sl: 20,
    tp: 40,
    time: new Date().toISOString()
  };
  socket.write(JSON.stringify(testTrade) + "\n", 'ascii');

  socket.on('data', data => {
    console.log('TCP Received:', data.toString());
    // (optional) Process TCP client messages here
  });

  socket.on('close', () => {
    tcpClients.delete(socket);
    console.log('TCP client disconnected');
  });

  socket.on('error', err => {
    tcpClients.delete(socket);
    console.error('TCP client error:', err);
  });
});

tcpServer.listen(TCP_PORT, () => {
  console.log(`TCP server listening on port ${TCP_PORT}`);
});

// For testing/demo, send a test trade every 30s to all clients (as ASCII)
setInterval(() => {
  const testTrade = {
    cmd: "BUY",
    symbol: "EURUSD",
    lot: 0.1,
    sl: 20,
    tp: 40,
    time: new Date().toISOString()
  };
  broadcastWS(testTrade);
  broadcastTCP(testTrade);
  console.log('Broadcast test trade:', testTrade);
}, 30000);

// --- HTTP server for /data endpoint (for MT5 EA WebRequest) ---
http.createServer((req, res) => {
  if (req.url === '/data') {
    // Example trade JSON (customize as needed)
    const trade = {
      cmd: "BUY",
      symbol: "EURUSD",
      lot: 0.1,
      sl: 20,
      tp: 40,
      time: new Date().toISOString()
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(trade));
  } else {
    res.writeHead(404);
    res.end();
  }
}).listen(HTTP_PORT, () => {
  console.log(`HTTP server listening on http://localhost:${HTTP_PORT}`);
});
