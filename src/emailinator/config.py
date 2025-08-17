import json
from pathlib import Path

CONFIG_PATH = Path(__file__).with_name("config.json")


def load_config():
    """Load configuration values from the config file."""
    with CONFIG_PATH.open() as f:
        return json.load(f)
