import sys
sys.path.append('src')

from emailinator.input.email_reader import read_email_file
from emailinator.processing.email_parser import extract_text_from_email


def test_extract_text():
    msg = read_email_file("tests/data/simple_email1.eml")
    text = extract_text_from_email(msg)
    assert "Task One" in text
    assert "Task Eleven" in text
