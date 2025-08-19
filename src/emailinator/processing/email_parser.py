from bs4 import BeautifulSoup

# User text/plain part if it is close enough in size to text/html part.
# Some email includes a placeholder text/plain part with no usable content.
PRIORITIZE_PLAIN_TEXT_THRESHOLD = 0.5


def extract_text_from_email(msg):
    """Extracts plain text from an email.message.Message object."""
    body = ""
    if msg.is_multipart():
        plain_text = ""
        html_text = ""
        for part in msg.walk():
            content_type = part.get_content_type()
            if content_type == "text/plain":
                # Plain text part, use as-is
                payload = part.get_payload(decode=True)
                if payload:
                    plain_text = payload.decode(
                        part.get_content_charset() or "utf-8", errors="replace"
                    )
            elif content_type == "text/html":
                # HTML part, strip tags
                payload = part.get_payload(decode=True)
                if payload:
                    html_content = payload.decode(
                        part.get_content_charset() or "utf-8", errors="replace"
                    )
                    soup = BeautifulSoup(html_content, "html.parser")
                    html_text = soup.get_text(separator="\n", strip=True)
        # Prioritize text/plain if it seems to be of comparable size.
        if len(plain_text) >= PRIORITIZE_PLAIN_TEXT_THRESHOLD * len(html_text):
            body = plain_text.strip()
        else:
            body = html_text.strip()
    else:
        body = msg.get_payload(decode=True).decode(errors="ignore")
    return body
