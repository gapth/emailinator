import email
from pathlib import Path


def read_email_file(path: str):
    """Reads a .eml file and returns an email.message.Message object."""
    path_obj = Path(path)
    if not path_obj.exists():
        raise FileNotFoundError(f"No such file: {path}")
    with open(path_obj, "rb") as f:
        return email.message_from_binary_file(f)


def read_email_bytes(data: bytes):
    """Parses raw email bytes into an email.message.Message object."""
    return email.message_from_bytes(data)
