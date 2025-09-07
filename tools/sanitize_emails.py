#!/usr/bin/env python3
"""
Email sanitization script for .eml files.

This script sanitizes .eml files by:
1. Keeping only specific headers: From, To, Bcc, Subject, Date, Message-Id
2. Keeping only content with text/plain and text/html Content-Type
3. Replacing all email addresses with "someone@somewhere.com"
4. Replacing all HTTP and HTTPS links with "https://a_link"
5. Replacing blocked words with random animal words from: cat, mouse, dog, cow, pig, chicken

Usage:
    python sanitize_emails.py --dir path/to/directory --block-words word1,word2,word3
"""

import argparse
import email
import email.utils
import os
import random
import re
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path


def replace_blocked_words(text: str, blocked_words: list) -> str:
    """
    Replace blocked words in the given text with random animal words.

    Args:
        text: Input text that may contain blocked words
        blocked_words: List of words to replace

    Returns:
        Text with all blocked words replaced with random animal words
    """
    if not blocked_words:
        return text

    # Animal words to replace blocked words with
    replacement_words = ["cat", "mouse", "dog", "cow", "pig", "chicken"]

    # Replace each blocked word with a random animal word
    result_text = text
    for word in blocked_words:
        if word.strip():  # Skip empty words
            # Use word boundaries to match whole words only
            pattern = r"\b" + re.escape(word.strip()) + r"\b"
            replacement = random.choice(replacement_words)
            result_text = re.sub(pattern, replacement, result_text, flags=re.IGNORECASE)

    return result_text


def replace_email_addresses(text: str) -> str:
    """
    Replace all email addresses in the given text with 'someone@somewhere.com'.

    Args:
        text: Input text that may contain email addresses

    Returns:
        Text with all email addresses replaced
    """
    # Email regex pattern - matches most common email formats
    email_pattern = r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"
    return re.sub(email_pattern, "someone@somewhere.com", text)


def replace_http_links(text: str) -> str:
    """
    Replace all HTTP and HTTPS links in the given text with 'https://a_link'.

    Args:
        text: Input text that may contain HTTP/HTTPS links

    Returns:
        Text with all HTTP/HTTPS links replaced
    """
    # HTTP/HTTPS URL regex pattern - matches most common URL formats
    url_pattern = r'https?://[^\s<>"{}|\\^`\[\]]*'
    return re.sub(url_pattern, "https://a_link", text)


def process_and_sanitize_payload(email_part, blocked_words):
    """
    Process and sanitize the payload of an email part by decoding, replacing
    email addresses, HTTP links, and blocked words, and returning the sanitized text.

    Args:
        email_part: An email message or part object
        blocked_words: List of words to replace with animal words

    Returns:
        str: Sanitized text payload
    """
    # Get the decoded payload for text replacement
    try:
        decoded_payload = email_part.get_payload(decode=True)
        if decoded_payload is not None:
            # Decode bytes to string using the charset from Content-Type
            charset = email_part.get_content_charset() or "utf-8"
            text_payload = decoded_payload.decode(charset, errors="replace")

            # Replace email addresses, HTTP links, and blocked words
            text_payload = replace_email_addresses(text_payload)
            text_payload = replace_http_links(text_payload)
            text_payload = replace_blocked_words(text_payload, blocked_words)

            return text_payload
        else:
            # Fallback to string payload if decoding fails
            payload = email_part.get_payload()
            if isinstance(payload, str):
                payload = replace_email_addresses(payload)
                payload = replace_http_links(payload)
                payload = replace_blocked_words(payload, blocked_words)
            return payload
    except (UnicodeDecodeError, LookupError):
        # If decoding fails, fall back to string replacement
        payload = email_part.get_payload()
        if isinstance(payload, str):
            payload = replace_email_addresses(payload)
            payload = replace_http_links(payload)
            payload = replace_blocked_words(payload, blocked_words)
        return payload


def sanitize_email(eml_content: str, blocked_words: list) -> str:
    """
    Sanitize an email by keeping only specified headers and content types.
    Preserves original Content-Transfer-Encoding and Content-Type (including charset).

    Args:
        eml_content: Raw .eml file content as string
        blocked_words: List of words to replace with animal words

    Returns:
        Sanitized email content as string
    """
    # Parse the email
    msg = email.message_from_string(eml_content)

    # Headers to keep
    headers_to_keep = {"From", "To", "Bcc", "Subject", "Date", "Message-Id"}

    # Create new message structure
    if msg.is_multipart():
        # Preserve the original multipart type and boundary
        new_msg = MIMEMultipart()
        # Copy the content type from original (preserves subtype like 'alternative')
        if "Content-Type" in msg:
            content_type_header = msg["Content-Type"]
            # Extract the multipart subtype
            if "multipart/" in content_type_header:
                subtype = (
                    content_type_header.split("multipart/")[1].split(";")[0].strip()
                )
                new_msg.set_type(f"multipart/{subtype}")
    else:
        new_msg = MIMEText("")

    # Copy specified headers
    for header in headers_to_keep:
        if header in msg:
            new_msg[header] = msg[header]

    # Process message content
    if msg.is_multipart():
        # Handle multipart messages - preserve original parts
        for part in msg.walk():
            # Skip the multipart container itself
            if part.is_multipart():
                continue

            content_type = part.get_content_type()

            if content_type in ["text/plain", "text/html"]:
                # Create new part preserving original encoding and content type
                new_part = MIMEText("")

                # Copy content type and charset
                new_part.set_type(content_type)
                if part.get_content_charset():
                    new_part.set_charset(part.get_content_charset())

                # Copy transfer encoding
                if "Content-Transfer-Encoding" in part:
                    new_part["Content-Transfer-Encoding"] = part[
                        "Content-Transfer-Encoding"
                    ]

                # Copy MIME version if present
                if "MIME-Version" in part:
                    new_part["MIME-Version"] = part["MIME-Version"]

                # Process and sanitize the payload
                sanitized_payload = process_and_sanitize_payload(part, blocked_words)
                new_part.set_payload(sanitized_payload)

                new_msg.attach(new_part)

    else:
        # Handle single part messages
        content_type = msg.get_content_type()

        if content_type in ["text/plain", "text/html"]:
            # Set the content type
            new_msg.set_type(content_type)
            if msg.get_content_charset():
                new_msg.set_charset(msg.get_content_charset())

            # Copy transfer encoding
            if "Content-Transfer-Encoding" in msg:
                new_msg["Content-Transfer-Encoding"] = msg["Content-Transfer-Encoding"]
            if "MIME-Version" in msg:
                new_msg["MIME-Version"] = msg["MIME-Version"]

            # Process and sanitize the payload
            sanitized_payload = process_and_sanitize_payload(msg, blocked_words)
            new_msg.set_payload(sanitized_payload)

    # Convert to string and do final email address, HTTP link, and blocked word replacement in headers
    sanitized_content = str(new_msg)
    sanitized_content = replace_email_addresses(sanitized_content)
    sanitized_content = replace_http_links(sanitized_content)
    sanitized_content = replace_blocked_words(sanitized_content, blocked_words)

    return sanitized_content


def process_eml_files(directory_path: str, blocked_words: list):
    """
    Process all .eml files in the specified directory.

    Args:
        directory_path: Path to directory containing .eml files
        blocked_words: List of words to replace with animal words
    """
    directory = Path(directory_path)

    if not directory.exists():
        print(f"Directory not found: {directory_path}")
        return

    # Find all .eml files
    eml_files = list(directory.glob("*.eml"))

    if not eml_files:
        print(f"No .eml files found in {directory_path}")
        return

    print(f"Found {len(eml_files)} .eml files to process...")

    for eml_file in eml_files:
        print(f"Processing: {eml_file.name}")

        try:
            # Read the original file
            with open(eml_file, "r", encoding="utf-8", errors="ignore") as f:
                original_content = f.read()

            # Sanitize the content
            sanitized_content = sanitize_email(original_content, blocked_words)

            # Write back to the same file
            with open(eml_file, "w", encoding="utf-8") as f:
                f.write(sanitized_content)

            print(f"✓ Successfully sanitized: {eml_file.name}")

        except Exception as e:
            print(f"✗ Error processing {eml_file.name}: {str(e)}")


def main():
    """Main function to run the sanitization process."""
    parser = argparse.ArgumentParser(
        description="Sanitize .eml files by replacing emails, links, and blocked words"
    )
    parser.add_argument(
        "--dir",
        required=True,
        help="Path to directory containing .eml files to sanitize",
    )
    parser.add_argument(
        "--block-words",
        help="Comma-separated list of words to replace with random animal words",
    )

    args = parser.parse_args()

    # Parse blocked words from comma-separated string
    blocked_words = []
    if args.block_words:
        blocked_words = [word.strip() for word in args.block_words.split(",")]

    print("Starting email sanitization process...")
    print(f"Target directory: {args.dir}")
    if blocked_words:
        print(f"Blocked words to replace: {', '.join(blocked_words)}")
    print("-" * 60)

    process_eml_files(args.dir, blocked_words)

    print("-" * 60)
    print("Email sanitization process completed!")


if __name__ == "__main__":
    main()
