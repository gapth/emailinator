from bs4 import BeautifulSoup

def extract_text_from_email(msg):
    """Extracts plain text from an email.message.Message object."""
    body = ""
    if msg.is_multipart():
        text_parts = []
        for part in msg.walk():
            content_type = part.get_content_type()
            if content_type == "text/plain":
                # Plain text part, use as-is
                payload = part.get_payload(decode=True)
                if payload:
                    text_parts.append(payload.decode(part.get_content_charset() or "utf-8", errors="replace"))
            elif content_type == "text/html":
                # HTML part, strip tags
                payload = part.get_payload(decode=True)
                if payload:
                    html_content = payload.decode(part.get_content_charset() or "utf-8", errors="replace")
                    soup = BeautifulSoup(html_content, "html.parser")
                    text_parts.append(soup.get_text(separator="\n", strip=True))
        # Join and deduplicate text parts
        combined_text = "\n".join(dict.fromkeys(text_parts))
        body = combined_text.strip()
    else:
        body = msg.get_payload(decode=True).decode(errors="ignore")
    return body
