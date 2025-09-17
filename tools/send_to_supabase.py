import argparse
import email
import json
import os
import sys
from email.header import decode_header, make_header
from email.message import Message
from email.utils import getaddresses
from pathlib import Path

import requests
from bs4 import BeautifulSoup


def read_email_file(path: str) -> Message:
    """Reads a .eml file and returns an email.message.Message object."""
    path_obj = Path(path)
    if not path_obj.exists():
        raise FileNotFoundError(f"No such file: {path}")
    with open(path_obj, "rb") as f:
        return email.message_from_binary_file(f)


def _decode_header(value: str | None) -> str | None:
    if value is None:
        return None
    try:
        return str(make_header(decode_header(value)))
    except Exception:
        return value


def _extract_bodies(msg: Message) -> tuple[str | None, str | None]:
    """Return (TextBody, HtmlBody).
    - Preserves raw HTML for HtmlBody when available (aligns with Postmark).
    - If only HTML exists, also synthesize TextBody by stripping HTML.
    """
    text_body: str | None = None
    html_body: str | None = None
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
                html_body = content  # keep raw HTML for HtmlBody
                # Synthesize text if not present yet
                if text_body is None:
                    soup = BeautifulSoup(content, "html.parser")
                    text_body = soup.get_text(separator="\n", strip=True)
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            try:
                content = payload.decode(charset, errors="replace")
            except Exception:
                content = payload.decode("utf-8", errors="replace")
            if msg.get_content_type() == "text/html":
                html_body = content
                # Synthesize text from HTML
                soup = BeautifulSoup(content, "html.parser")
                text_body = soup.get_text(separator="\n", strip=True)
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
        help="Supabase inbound-email function URL",
    )
    parser.add_argument(
        "--alias",
        required=True,
        help="Alias for the email address",
    )
    args = parser.parse_args()

    user = os.getenv("POSTMARK_BASIC_USER")
    password = os.getenv("POSTMARK_BASIC_PASSWORD")
    if not user or not password:
        raise EnvironmentError(
            "POSTMARK_BASIC_USER and POSTMARK_BASIC_PASSWORD must be set in the environment"
        )

    # Set default URL if not provided
    if not args.url:
        args.url = (
            f"http://{user}:{password}@localhost:54321/functions/v1/inbound-email"
        )

    msg = read_email_file(args.file)
    from_email = _decode_header(msg.get("From"))
    to_email = _decode_header(msg.get("To"))
    subject = _decode_header(msg.get("Subject"))
    sent_at = _decode_header(msg.get("Date"))
    message_id = _decode_header(msg.get("Message-ID"))
    text_body, html_body = _extract_bodies(msg)

    # Build Postmark-style Headers array at top level
    headers_list: list[dict[str, str]] = []
    for name, value in msg.items():
        headers_list.append({"Name": name, "Value": _decode_header(value) or ""})

    # Build Postmark-style Full address arrays when possible
    def _full_from_header(header_value: str | None) -> list[dict[str, str]]:
        if not header_value:
            return []
        result: list[dict[str, str]] = []
        for name, email_addr in getaddresses([header_value]):
            result.append(
                {
                    "Email": email_addr or "",
                    "Name": name or "",
                    "MailboxHash": "",
                }
            )
        return result

    # Tell inbound-email which alias this email is for by BCCing it to that address.
    # The edge function will use that to look up the user.
    bcc_email = args.alias

    # Force X-Forwarded-For so the edge function treats the request as coming from localhost.
    headers = {"X-Forwarded-For": "127.0.0.1"}
    print("Header:")
    print(json.dumps(headers, indent=2, ensure_ascii=False))
    print()

    # Use Postmark-style field names that the inbound-email function currently expects.
    payload = {
        "From": from_email,
        "To": to_email,
        "Bcc": bcc_email,
        "OriginalRecipient": bcc_email,
        "Subject": subject,
        "TextBody": text_body,
        "HtmlBody": html_body,
        "Date": sent_at,
        "MessageID": message_id,
        "ToFull": _full_from_header(to_email),
        "CcFull": _full_from_header(_decode_header(msg.get("Cc"))),
        "BccFull": [{"Email": bcc_email, "Name": "", "MailboxHash": ""}],
        "Headers": headers_list,
        "ProviderMeta": {"source": "cli"},
    }
    print("Payload:")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    print()

    resp = requests.post(args.url, json=payload, auth=(user, password), headers=headers)
    print(f"Status: {resp.status_code}")
    try:
        print(resp.json())
    except Exception:
        print(resp.text)

    # Exit with return code based on HTTP status
    # 2xx status codes are considered success (exit code 0)
    # All other status codes are considered failure (exit code 1)
    if 200 <= resp.status_code < 300:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
