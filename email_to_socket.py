import imaplib
import email
import time
import socket
import ssl
import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

EMAIL = 'yourtrading_view_email@gmail.com'
PASSWORD = 'Gmail 2F App pasword'
SERVER = 'imap.gmail.com'
SOCKET_HOST = '127.0.0.1'
SOCKET_PORT = 3000
AES_KEY = 'MyAESPassphrase'

def connect_socket():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((SOCKET_HOST, SOCKET_PORT))
    return s

def get_email_body(msg):
    # Handles multipart and plain emails safely
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

def read_emails():
    mail = imaplib.IMAP4_SSL(SERVER)
    try:
        mail.login(EMAIL, PASSWORD)
    except imaplib.IMAP4.error as e:
        print("Login failed:", e)
        return
    mail.select('inbox')

    result, data = mail.search(None, '(UNSEEN)')
    if result != 'OK':
        print("Failed to search emails")
        mail.logout()
        return

    for num in data[0].split():
        result, msg_data = mail.fetch(num, '(RFC822)')
        if result != 'OK':
            print("Failed to fetch email", num)
            continue

        msg = email.message_from_bytes(msg_data[0][1])
        payload = get_email_body(msg)
        if not payload:
            print(f"No readable payload in email {num.decode() if isinstance(num, bytes) else num}")
            mail.store(num, '+FLAGS', '\\Seen')
            continue

        print("New Alert:", payload)
        send_to_mt5(payload)

        mail.store(num, '+FLAGS', '\\Seen')

    mail.logout()

def send_to_mt5(json_payload):
    key = AES_KEY.encode().ljust(32, b'\0')
    iv = b'\0'*16
    cipher = AES.new(key, AES.MODE_CBC, iv)
    ct = cipher.encrypt(pad(json_payload.encode(), AES.block_size))
    encoded = base64.b64encode(ct).decode()

    try:
        sock = connect_socket()
        sock.send(encoded.encode())
        sock.close()
        print("Sent to MT5.")
    except Exception as e:
        print("Socket send failed:", e)

if __name__ == "__main__":
    while True:
        read_emails()
        time.sleep(10)  # Check every 10 seconds