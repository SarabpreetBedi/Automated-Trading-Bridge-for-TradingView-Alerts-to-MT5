🚀 **TradingView to MT4/MT5 Bridge**

![](images/Screenshot19.png)

Secure, Real-Time Bridge Between TradingView Alerts and MetaTrader 4/5

📌 Overview
This project enables auto-execution of TradingView alerts on MetaTrader 4/5 via a secure, encrypted bridge. Designed for low-latency trading and multi-broker compatibility, it supports any instrument on both demo and live accounts.

🔧 Components:
🖧 Node.js Server – Receives webhook alerts via secure WebSocket (WSS).

🤖 MT5 Expert Advisor (EA) – Executes trades based on received alerts.

🗂️ Project Structure

![](images/Screenshot14.png)


🖥️ Setup Guide (Windows 11)

1️⃣ Install Prerequisites

Tool	Link

Node.js	https://nodejs.org

MetaTrader5	Download MT5

OpenSSL	Win32 OpenSSL

💡 Tip: Use Git Bash (comes with OpenSSL)

2️⃣ Setup Node.js Server

cd path\to\bridge\server

npm install

3️⃣ Generate SSL Certificates (For Testing)

Run the following commands in PowerShell or Git Bash:

mkdir certs

openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout certs/server.key -out certs/server.crt \
  -days 365 -subj "/CN=localhost"
  
📁 Place server.key and server.crt in bridge/server/certs/

4️⃣ Create .env File

SECRET=SuperSecret123

AES_PASS=MyAESPassphrase

🔒 Keep this file secure. Keys must match your EA.

5️⃣ Run the Server

node server.js

✅ Server is live at https://localhost:3000

6️⃣ Setup MetaTrader 5 EA

Copy BridgeEA.mq5 to:  folder MQL5/Experts/

a)Open MetaEditor, compile BridgeEA.mq5, BridgeEA2.mq5.

b)Attach the EA to any chart.

c)Configure Inputs:

  SocketServer: 127.0.0.1
  
  SocketPort: 3000
  
  AES_PASS: Same as in .env
  
  RetrySec: 10

📡 EA will connect to the Node.js server and listen for alerts.

🧪 Testing Alerts

Sample JSON Alert:

{
  "secret": "SuperSecret123",
  "cmd": "BUY",
  "symbol": "EURUSD",
  "lot": 0.1,
  "sl": 1.20,
  "tp": 1.25,
  "magic": 123456,
  "trail": 0.03
}

Send to:

https://localhost:3000/webhook

Use a tool like Postman or curl.

📚 MQL5 Libraries Needed

Library	Purpose

1)SocketLib.mqh	WebSocket/TCP Client

2)Base64.mqh	Encode/Decode Base64

3)JSON.mqh	JSON Parsing (MQL5 Codebase)

📥 Get them from: MQL5 Codebase

📬 Alternative: Email-to-Socket (For Free TradingView Accounts)

📧 Send alerts via email instead of webhook.

Run the script:

cd bridge/

python3 email_to_socket.py

Configure TradingView:

Enable "Send Email"

Add your alert email address

Use JSON format in message body


{
  "secret": "SuperSecret123",
  "cmd": "BUY",
  "symbol": "EURUSD",
  "lot": 0.1,
  "sl": 1.2000,
  "tp": 1.2100,
  "magic": 123456
}
The script:

Logs into your Gmail

Reads new TradingView alerts

Sends decrypted payload to MT5 bridge

🔁 Runs every 10 seconds

🔗 Useful Links

Node.js  & npm: https://nodejs.org/

MetaTrader 5  https://www.metatrader5.com/en/download

OpenSSL for Windows: https://slproweb.com/products/Win32OpenSSL.html


🛡️ Notes & Best Practices

🔒 Use CA-signed SSL certificates in production

🔑 Keep AES and secret keys secure

📜 Log file: BridgeHistory.log

🧩 Easily extend EA to support multi-broker/multi-account setups

🖼️ Screenshots
MetaTrader EA Connected

![](images/Screenshot20.png)

TradingView Alert Setup

![](images/Screenshot15.png)
![](images/Screenshot16.png)

❤️ Contributing
Pull requests and issue reports are welcome. Please fork the repo and open a PR with clear commits.

📄 License
MIT License – see the LICENSE file for details.
