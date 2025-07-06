import fs from "fs";
import crypto from "crypto";
const secret = "SuperSecret123";
const body = fs.readFileSync("sample_alert.json");
const sig = crypto.createHmac("sha256", secret).update(body).digest("hex");
console.log("x-signature:", sig);
