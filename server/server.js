import express from "express";
import https from "https";
import fs from "fs";
import { WebSocketServer } from "ws";
import crypto from "crypto";
import dotenv from "dotenv";
dotenv.config();

const PORT = process.env.PORT || 3000;
const SECRET = process.env.SECRET;
const AES_PASS = process.env.AES_PASS;

const app = express();
app.use(express.json());

const server = https.createServer({
  key: fs.readFileSync("certs/server.key"),
  cert: fs.readFileSync("certs/server.crt")
}, app);

const wss = new WebSocketServer({ server });
const sockets = new Set();

wss.on("connection", ws => {
  console.log("EA connected");
  sockets.add(ws);
  ws.on("close", () => sockets.delete(ws));
});

function encrypt(data) {
  const iv = Buffer.alloc(16, 0); // Fixed IV (16 bytes of zeros)
  const key = crypto.scryptSync(AES_PASS, "salt", 32);
  const cipher = crypto.createCipheriv("aes-256-cbc", key, iv);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  return encrypted.toString("base64");  // Directly return base64 (no IV prefix)
}

app.post("/webhook", (req, res) => {
  const sig = req.headers["x-signature"];
  const body = JSON.stringify(req.body);
  const hmac = crypto.createHmac("sha256", SECRET).update(body).digest("hex");
  if (sig !== hmac) return res.status(403).send("Invalid signature");

  const payload = JSON.stringify(req.body);
  const encryptedMsg = encrypt(payload);
  const logLine = `${new Date().toISOString()} | ${payload}\n`;
  fs.appendFileSync("server.log", logLine);

  sockets.forEach(ws => ws.readyState === 1 && ws.send(encryptedMsg));
  res.status(200).send("OK");
});

server.listen(PORT, () => console.log(`HTTPS WebSocket server on port ${PORT}`));
