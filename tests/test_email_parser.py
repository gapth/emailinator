import sys

sys.path.append("src")

from emailinator.input.email_reader import read_email_file
from emailinator.processing.email_parser import extract_text_from_email


def test_extract_text_prioritize_plain_text():
    msg = read_email_file("tests/data/plain_and_html_comparable.eml")
    text = extract_text_from_email(msg)
    assert "Task One" in text
    assert "Task Eleven" not in text


def test_extract_text_use_html_if_plain_too_short():
    msg = read_email_file("tests/data/plain_too_short.eml")
    text = extract_text_from_email(msg)
    assert "placeholder" not in text
    assert "Task Eleven" in text


def test_extract_text_full_html():
    msg = read_email_file("tests/data/full_html_email.eml")
    text = extract_text_from_email(msg)
    assert "Colours Uniforms" in text
