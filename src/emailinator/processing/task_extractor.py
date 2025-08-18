import os
import logging

from dotenv import load_dotenv
from openai import OpenAI

from emailinator.storage.models import Task
from emailinator.storage.schema_utils import sqlalchemy_to_jsonschema

# === Constants ===
MODEL_NAME = "gpt-4.1-mini"
INPUT_USD_PER_TOKEN = 0.4e-6
OUTPUT_USD_PER_TOKEN = 1.6e-6

# JSON schema shared by task extraction methods
TASK_SCHEMA = {
    "name": "tasks_list",
    "schema": {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "Extracted School Tasks",
        "description": "A deduplicated, grouped list of tasks. If several lines describe the same overall activity (e.g., multiple retreat forms), merge them into one task and enumerate details in `description`.",
        "type": "object",
        "properties": {
            "tasks": {
                "type": "array",
                "description": "A deduplicated, grouped list of tasks. If several lines describe the same overall activity, merge them and enumerate details in `description`.",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "description": "One actionable item that a parent and/or student must complete, attend, or prepare for.",
                    "properties": {
                        "title": {"type": "string", "description": "Short (less than 30 characters) topic-only label for grouping and future matching. Do NOT include verbs if avoidable. Examples: 'Permission form', 'Tie Ceremony', 'Picture Day', 'Athletics forms', 'Locker assignments'."},
                        "description": {"type": "string", "description": "Concise but complete summary incl. who/what/where/when and options; list sub-steps and extra dates if merged."},
                        "due_date": {"type": "string", "format": "date", "description": "YYYY-MM-DD deadline if explicitly stated; otherwise omit."},
                        "consequence_if_ignore": {"type": "string", "description": "Natural-language consequence; infer if implicit."},
                        "parent_action": {
                            "type": "string",
                            "enum": ["NONE","SUBMIT","SIGN","PAY","PURCHASE","ATTEND","TRANSPORT","VOLUNTEER","OTHER"],
                            "description": "Parent’s single action. If multiple implied, choose one by priority: ATTEND > PAY > SUBMIT > SIGN > PURCHASE > TRANSPORT > VOLUNTEER > OTHER > NONE."
                        },
                        "parent_requirement_level": {
                            "type": "string",
                            "enum": ["NONE","OPTIONAL","VOLUNTEER_OPPORTUNITY","MANDATORY"],
                            "description": "MANDATORY if required or a consequence stated; VOLUNTEER_OPPORTUNITY if explicitly seeking volunteers; OPTIONAL if encouraged; NONE if no parent action."
                        },
                        "student_action": {
                            "type": "string",
                            "enum": ["NONE","SUBMIT","ATTEND","SETUP","BRING","PREPARE","WEAR","COLLECT","OTHER"],
                            "description": "Student’s single action. If multiple implied, choose one by priority: ATTEND > SUBMIT > SETUP > WEAR > BRING > COLLECT > PREPARE > OTHER > NONE."
                        },
                        "student_requirement_level": {
                            "type": "string",
                            "enum": ["NONE","OPTIONAL","VOLUNTEER_OPPORTUNITY","MANDATORY"],
                            "description": "MANDATORY if required or a consequence stated; VOLUNTEER_OPPORTUNITY if student volunteering; OPTIONAL if encouraged; NONE if no student action."
                        }
                    },
                    "required": ["title"]
                }
            }
        },
        "required": ["tasks"],
        "additionalProperties": False
    }
}

load_dotenv()  # Load .env file if present

api_key = os.getenv("OPENAI_API_KEY")
client = OpenAI(api_key=api_key) if api_key else None

def extract_tasks_from_text(email_text: str) -> list[dict]:
    """Uses OpenAI API to extract tasks from an email string."""
    schema = TASK_SCHEMA

    prompt = (
        """You are a careful assistant for a busy parent. 
        Extract a **deduplicated list** of tasks from the email. 
        Only include actionable items (forms, payments, events, purchases, transport, volunteering). 
        **Merge** lines that describe the same activity into a single task and enumerate details in `description`. 
        Ignore narrative, greetings, kudos, essays, and general updates. 
        If an event requires attire, **do not** create a separate task for clothing; note attire inside `description` and set `student_action` using the priority rules.
        If multiple actions are implied, pick exactly one per actor using these priorities:
        - parent_action priority: ATTEND > PAY > SUBMIT > SIGN > PURCHASE > TRANSPORT > VOLUNTEER > OTHER > NONE
        - student_action priority: ATTEND > SUBMIT > SETUP > WEAR > BRING > COLLECT > PREPARE > OTHER > NONE
        For `due_date`, pick the **earliest explicit date** related to that task; list later dates in `description`.
        Infer a practical `consequence_if_ignore` if unstated.
        Return **only** valid JSON that conforms to the provided JSON Schema. No prose.
        """
    )

    if client is None:
        raise RuntimeError("OPENAI_API_KEY is not set")

    resp = client.chat.completions.create(
        model=MODEL_NAME,
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": f"Extract tasks from this email:\n\n{email_text}"}
        ],
        response_format={"type": "json_schema", "json_schema": schema}
        # Not available on GPT-5
        # temperature=0.1,
        # top_p=1
    )
    # Log usages
    api_cost = (
        resp.usage.prompt_tokens * INPUT_USD_PER_TOKEN
        + resp.usage.completion_tokens * OUTPUT_USD_PER_TOKEN
    )

    logger = logging.getLogger("emailinator")
    logger.info(f"API cost (USD): {api_cost:.6f}")

    import json

    data = json.loads(resp.choices[0].message.content)
    tasks = data.get("tasks", [])
    logger.info(f"Extracted {len(tasks)} tasks")
    return tasks


def extract_deduplicated_tasks(email_text: str, existing_tasks: list[dict]) -> list[dict]:
    """Extract tasks and deduplicate them with an existing task list."""
    schema = TASK_SCHEMA

    prompt = (
        """You are a careful assistant for a busy parent.\n"
        "You are given an existing list of tasks and a new email.\n"
        "Combine the existing tasks with any tasks found in the email, \n"
        "merging entries that describe the same activity.\n"
        "Return the full deduplicated list of tasks.\n"
        "Only include actionable items (forms, payments, events, purchases, transport, volunteering).\n"
        "If an event requires attire, do not create a separate task for clothing; note attire inside `description`.\n"
        "Return only valid JSON that conforms to the provided JSON Schema. No prose."""
    )

    if client is None:
        raise RuntimeError("OPENAI_API_KEY is not set")

    import json

    existing_json = json.dumps({"tasks": existing_tasks})

    resp = client.chat.completions.create(
        model=MODEL_NAME,
        messages=[
            {"role": "system", "content": prompt},
            {
                "role": "user",
                "content": f"Existing tasks:\n{existing_json}\n\nEmail:\n{email_text}",
            },
        ],
        response_format={"type": "json_schema", "json_schema": schema},
    )

    api_cost = (
        resp.usage.prompt_tokens * INPUT_USD_PER_TOKEN
        + resp.usage.completion_tokens * OUTPUT_USD_PER_TOKEN
    )

    logger = logging.getLogger("emailinator")
    logger.info(f"API cost (USD): {api_cost:.6f}")

    data = json.loads(resp.choices[0].message.content)
    tasks = data.get("tasks", [])
    logger.info(f"Extracted {len(tasks)} tasks after deduplication")
    return tasks
