import argparse
from email.message import Message
from email.header import decode_header, make_header

from bs4 import BeautifulSoup
from emailinator.input.email_reader import read_email_file
import requests


def _decode_header(value: str | None) -> str | None:
    if value is None:
        return None
    try:
        return str(make_header(decode_header(value)))
    except Exception:
        return value


def _extract_bodies(msg: Message) -> tuple[str | None, str | None]:
    text_body = None
    html_body = None
    if msg.is_multipart():
        for part in msg.walk():
            ctype = part.get_content_type()
            payload = part.get_payload(decode=True)
            if not payload:
                continue
            charset = part.get_content_charset() or "utf-8"
            try:
                content = payload.decode(charset, errors="replace")
            except Exception:
                content = payload.decode("utf-8", errors="replace")
            if ctype == "text/plain" and text_body is None:
                text_body = content
            elif ctype == "text/html" and html_body is None:
                soup = BeautifulSoup(content, "html.parser")
                html_body = soup.get_text(separator="\n", strip=True)
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            try:
                content = payload.decode(charset, errors="replace")
            except Exception:
                content = payload.decode("utf-8", errors="replace")
            if msg.get_content_type() == "text/html":
                soup = BeautifulSoup(content, "html.parser")
                html_body = soup.get_text(separator="\n", strip=True)
            else:
                text_body = content
    return text_body, html_body


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Submit a .eml file to the Supabase inbound-email function",
    )
    parser.add_argument("--file", required=True, help="Path to .eml file")
    parser.add_argument(
        "--url",
        default="http://localhost:54321/functions/v1/inbound-email",
        help="Supabase inbound-email function URL",
    )
    parser.add_argument(
        "--access-token",
        required=True,
        help="Supabase JWT for the user",
    )
    args = parser.parse_args()

    msg = read_email_file(args.file)
    from_email = _decode_header(msg.get("From"))
    to_email = _decode_header(msg.get("To"))
    subject = _decode_header(msg.get("Subject"))
    text_body, html_body = _extract_bodies(msg)

    payload = {
        "from_email": from_email,
        "to_email": to_email,
        "subject": subject,
        "text_body": text_body,
        "html_body": html_body,
        "provider_meta": {"source": "cli"},
    }

    headers = {
        "Authorization": f"Bearer {args.access_token}",
        "Content-Type": "application/json",
    }

    resp = requests.post(args.url, headers=headers, json=payload)
    print(f"Status: {resp.status_code}")
    try:
        print(resp.json())
    except Exception:
        print(resp.text)


if __name__ == "__main__":
    main()
