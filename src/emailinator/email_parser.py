from .openai_client import extract_tasks_with_ai

def extract_tasks(email_text: str) -> list[str]:
    # You can add pre-processing here before sending to AI
    return extract_tasks_with_ai(email_text)
