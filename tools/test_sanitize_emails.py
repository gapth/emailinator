#!/usr/bin/env python3
"""
Tests for the sanitize_emails.py functionality.
"""

import base64
import email

from tools.sanitize_emails import (
    replace_blocked_words,
    replace_email_addresses,
    replace_http_links,
    sanitize_email,
)


def test_replace_email_addresses():
    """Test that email addresses are properly replaced."""
    text = "Contact us at support@example.com or admin@test.org"
    result = replace_email_addresses(text)
    assert "someone@somewhere.com" in result
    assert "support@example.com" not in result
    assert "admin@test.org" not in result


def test_replace_http_links():
    """Test that HTTP links are properly replaced."""
    text = "Visit https://example.com or http://test.org for more info"
    result = replace_http_links(text)
    assert "https://a_link" in result
    assert "https://example.com" not in result
    assert "http://test.org" not in result


def test_sanitize_email_with_encoded_content():
    """Test that encoded email content is properly decoded, sanitized, and re-encoded."""
    # Create a test email with base64 encoded content containing email addresses
    original_text = "Contact us at support@example.com or visit https://example.com"
    encoded_content = base64.b64encode(original_text.encode("utf-8")).decode("ascii")

    eml_content = f"""From: sender@example.com
To: recipient@example.com
Subject: Test Email
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: base64

{encoded_content}
"""

    # Sanitize the email
    result = sanitize_email(eml_content, [])

    # Parse the result to check the content
    msg = email.message_from_string(result)
    decoded_payload = msg.get_payload(decode=True).decode("utf-8")

    # Verify that email addresses and links were replaced
    assert "someone@somewhere.com" in decoded_payload
    assert "https://a_link" in decoded_payload
    assert "support@example.com" not in decoded_payload
    assert "https://example.com" not in decoded_payload


def test_sanitize_email_multipart_with_encoded_content():
    """Test multipart email with encoded content."""
    # Create a test multipart email with base64 encoded content
    original_text = "Contact us at support@example.com or visit https://example.com"
    encoded_content = base64.b64encode(original_text.encode("utf-8")).decode("ascii")

    eml_content = f"""From: sender@example.com
To: recipient@example.com
Subject: Test Email
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="boundary123"

--boundary123
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: base64

{encoded_content}

--boundary123
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: base64

{base64.b64encode(f'<p>{original_text}</p>'.encode('utf-8')).decode('ascii')}

--boundary123--
"""

    # Sanitize the email
    result = sanitize_email(eml_content, [])

    # Parse the result to check the content
    msg = email.message_from_string(result)

    # Check each part
    for part in msg.walk():
        if not part.is_multipart():
            content_type = part.get_content_type()
            if content_type in ["text/plain", "text/html"]:
                decoded_payload = part.get_payload(decode=True).decode("utf-8")

                # Verify that email addresses and links were replaced
                assert "someone@somewhere.com" in decoded_payload
                assert "https://a_link" in decoded_payload
                assert "support@example.com" not in decoded_payload
                assert "https://example.com" not in decoded_payload


def test_sanitize_email_headers():
    """Test that headers are properly sanitized."""
    eml_content = """From: sender@example.com
To: recipient@example.com
Subject: Test Email with https://example.com
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

Simple text content.
"""

    # Sanitize the email
    result = sanitize_email(eml_content, [])

    # Verify that email addresses and links in headers were replaced
    assert "someone@somewhere.com" in result
    assert "https://a_link" in result
    assert "sender@example.com" not in result
    assert "recipient@example.com" not in result
    assert "https://example.com" not in result


def test_replace_blocked_words():
    """Test that blocked words are properly replaced with animal words."""
    text = "The password is secret123 and the confidential information is here."
    blocked_words = ["password", "secret123", "confidential"]
    result = replace_blocked_words(text, blocked_words)

    # Check that original words are gone
    assert "password" not in result.lower()
    assert "secret123" not in result.lower()
    assert "confidential" not in result.lower()

    # Check that animal words are present
    animal_words = ["cat", "mouse", "dog", "cow", "pig", "chicken"]
    total_animal_count = sum(result.lower().count(word) for word in animal_words)
    assert (
        total_animal_count >= 3
    )  # Should have at least 3 animal word occurrences (one for each blocked word)


def test_replace_blocked_words_case_insensitive():
    """Test that blocked words matching is case-insensitive."""
    text = "The PASSWORD and Secret123 are CONFIDENTIAL."
    blocked_words = ["password", "secret123", "confidential"]
    result = replace_blocked_words(text, blocked_words)

    # Check that original words are gone (case insensitive)
    assert "password" not in result.lower()
    assert "secret123" not in result.lower()
    assert "confidential" not in result.lower()
    assert "PASSWORD" not in result
    assert "Secret123" not in result
    assert "CONFIDENTIAL" not in result


def test_sanitize_email_with_blocked_words():
    """Test that sanitize_email properly replaces blocked words."""
    eml_content = """From: admin@example.com
To: user@example.com
Subject: Your password reset
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

Your password is secret123. Please keep this confidential.
"""

    blocked_words = ["password", "secret123", "confidential"]
    result = sanitize_email(eml_content, blocked_words)

    # Check that blocked words are replaced
    assert "password" not in result.lower()
    assert "secret123" not in result.lower()
    assert "confidential" not in result.lower()

    # Check that email addresses are still replaced
    assert "someone@somewhere.com" in result
    assert "admin@example.com" not in result


if __name__ == "__main__":
    # Run tests without pytest
    test_replace_email_addresses()
    print("✓ test_replace_email_addresses passed")

    test_replace_http_links()
    print("✓ test_replace_http_links passed")

    test_replace_blocked_words()
    print("✓ test_replace_blocked_words passed")

    test_replace_blocked_words_case_insensitive()
    print("✓ test_replace_blocked_words_case_insensitive passed")

    test_sanitize_email_with_encoded_content()
    print("✓ test_sanitize_email_with_encoded_content passed")

    test_sanitize_email_multipart_with_encoded_content()
    print("✓ test_sanitize_email_multipart_with_encoded_content passed")

    test_sanitize_email_with_blocked_words()
    print("✓ test_sanitize_email_with_blocked_words passed")

    test_sanitize_email_headers()
    print("✓ test_sanitize_email_headers passed")

    print("\nAll tests passed! ✅")
