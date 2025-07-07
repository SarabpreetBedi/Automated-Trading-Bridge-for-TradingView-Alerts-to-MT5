import socket
import imaplib
import email
import json
import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad
import time

EMAIL = 'your_tradingview_email@gmail.com'
PASSWORD = '2F Apps password'
SERVER = 'imap.gmail.com'
SOCKET_HOST = '127.0.0.1'
SOCKET_PORT = 3000
AES_KEY = 'MyAESPassphrase'

def get_email_body(msg):
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            content_disposition = str(part.get("Content-Disposition"))
            if content_type == "text/plain" and "attachment" not in content_disposition:
                payload = part.get_payload(decode=True)
                if payload:
                    return payload.decode(errors="ignore")
        return None
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            return payload.decode(errors="ignore")
        return None

def fetch_unread_emails():
    mail = imaplib.IMAP4_SSL(SERVER)
    try:
        mail.login(EMAIL, PASSWORD)
    except imaplib.IMAP4.error as e:
        print("Login failed:", e)
        return []
    mail.select('inbox')
    result, data = mail.search(None, '(UNSEEN)')
    if result != 'OK':
        print("Failed to search emails")
        mail.logout()
        return []
    emails = []
    for num in data[0].split():
        result, msg_data = mail.fetch(num, '(RFC822)')
        if result != 'OK':
            continue
        msg = email.message_from_bytes(msg_data[0][1])
        payload = get_email_body(msg)
        if not payload:
            continue
        # Build the JSON payload as you want
        json_payload = json.dumps({
            "secret": "SuperSecret123",
            "cmd": "BUY",
            "symbol": "EURUSD",
            "lot": 0.1,
            "sl": 20,
            "tp": 40,
            "magic": 111,
            "account": "Acct1"
        })
        emails.append(json_payload)
    mail.logout()
    return emails

def encrypt_payload(json_payload):
    key = AES_KEY.encode().ljust(32, b'\0')
    iv = b'\0'*16
    cipher = AES.new(key, AES.MODE_CBC, iv)
    ct = cipher.encrypt(pad(json_payload.encode(), AES.block_size))
    encoded = base64.b64encode(ct).decode()
    return encoded

def start_server():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((SOCKET_HOST, SOCKET_PORT))
        server.listen(1)
        print(f"[+] Listening on {SOCKET_HOST}:{SOCKET_PORT}")
        while True:
            conn, addr = server.accept()
            with conn:
                print(f"[+] Connection from {addr}")
                emails = fetch_unread_emails()
                if not emails:
                    print("[!] No unread emails to send.")
                    conn.sendall(b"No unread emails.\n")
                else:
                    for json_payload in emails:
                        encrypted = encrypt_payload(json_payload)
                        print(f"[>] Sending encrypted payload:\n{encrypted}\n")
                        conn.sendall(encrypted.encode() + b"\n")
                        response = b""
                        # Wait for response from EA
                        try:
                            while True:
                                chunk = conn.recv(1024)
                                if not chunk:
                                    break
                                response += chunk
                            print(f"[<] Response from EA: {response.decode(errors='ignore')}")
                        except Exception as e:
                            print(f"[!] Error receiving response: {e}")

if __name__ == "__main__":
    start_server()
