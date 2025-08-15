import os
from openai import OpenAI
from dotenv import load_dotenv
from emailinator.storage.models import Task
from emailinator.storage.schema_utils import sqlalchemy_to_jsonschema

load_dotenv()  # Load .env file if present

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def extract_tasks_from_text(text: str):
    """
    Placeholder: convert email text into a list of tasks.
    In production, this would call OpenAI API and parse JSON.
    """
    print(sqlalchemy_to_jsonschema(Task))
    tasks = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        tasks.append({"title": line, "description": "Extracted from email"})
    return tasks

def extract_tasks_with_ai(email_text: str) -> list[str]:
    """
    Uses OpenAI API to extract tasks from an email string.
    """
    prompt = f"Extract all actionable tasks from this email:\n\n{email_text}"
    resp = client.responses.create(
        model="gpt-4o-mini",
        input=prompt
    )
    return resp.output_text.strip().split("\n")
