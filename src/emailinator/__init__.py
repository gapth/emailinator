"""
Emailinator — Extract tasks from emails using OpenAI API.

This package auto-loads environment variables from `.env`
and exposes key functions at the top level for convenience.
"""

# Load environment variables automatically
from dotenv import load_dotenv
load_dotenv()

# Import public API
from .email_parser import extract_tasks
from .openai_client import extract_tasks_with_ai

# Define what gets exported when using `from emailinator import ...`
__all__ = ["extract_tasks", "extract_tasks_with_ai"]
