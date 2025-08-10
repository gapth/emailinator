import os
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()  # Load .env file if present

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

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