import os
import imaplib
import email
import json
from datetime import datetime
import time

# Email login credentials
EMAIL = 'bedisarabpreet@gmail.com'
PASSWORD = 'sswh okvu viai iaov'
SERVER = 'imap.gmail.com'

# MT5 "Files" folder path
MT5_FILES_DIR = "C:/Users/bedis/AppData/Roaming/MetaQuotes/Terminal/D0E8209F77C8CF37AD8BF550E51FF075/MQL5/Files/"

# Expected JSON structure
REQUIRED_KEYS = {
    "secret": str,
    "cmd": str,
    "symbol": str,
    "lot": float,
    "sl": int,
    "tp": int,
    "magic": int,
    "account": str
}

def is_valid_payload(payload):
    if not isinstance(payload, dict):
        return False
    for key, expected_type in REQUIRED_KEYS.items():
        if key not in payload:
            return False
        value = payload[key]
        if expected_type == int and isinstance(value, float):
            payload[key] = int(value)
        if not isinstance(payload[key], expected_type):
            return False
    return True

def extract_json_from_subject(subject):
    prefix = "Alert:"
    if subject.startswith(prefix):
        json_part = subject[len(prefix):].strip()
        return json_part
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

    messages = []
    for num in data[0].split():
        result, msg_data = mail.fetch(num, '(RFC822)')
        if result != 'OK':
            continue
        msg = email.message_from_bytes(msg_data[0][1])
        subject = msg['subject']
        if not subject:
            continue

        json_string = extract_json_from_subject(subject)
        if not json_string:
            print("[⚠️] Subject does not start with 'Alert:'. Skipping.")
            continue

        try:
            json_data = json.loads(json_string)
            if is_valid_payload(json_data):
                print("[✅] Valid email subject JSON found.")
                messages.append(json.dumps(json_data))  # Save as JSON string
            else:
                print("[⚠️] Invalid JSON structure in subject. Skipped.")
        except json.JSONDecodeError:
            print("[⚠️] Subject JSON is malformed. Skipped.")

    mail.logout()
    return messages

def save_text_to_file(text):
    now = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    filename = os.path.join(MT5_FILES_DIR, f"{now}.txt")
    try:
        with open(filename, "w", encoding="mbcs") as f:
            f.write(text)
        print(f"[💾] Saved email to: {filename}")
    except Exception as e:
        print(f"[❌] Failed to write file: {e}")

def main():
    print("[*] Checking for unread emails...")
    emails = fetch_unread_emails()

    if not emails:
        print("[!] No valid unread email subjects found.")
        return

    for email_text in emails:
        save_text_to_file(email_text)
        time.sleep(1)

if __name__ == "__main__":
    while True:
        main()
        time.sleep(15)  # Check every 15 seconds
