import os
from openai import OpenAI
from dotenv import load_dotenv
from emailinator.storage.models import Task
from emailinator.storage.schema_utils import sqlalchemy_to_jsonschema

load_dotenv()  # Load .env file if present

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def extract_tasks_from_text(email_text: str) -> list[dict]:
    """
    Uses OpenAI API to extract tasks from an email string, explicitly passing the JSON schema.
    """
    schema = {
            "name": "tasks_list",
            "schema": {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "title": "Extracted School Tasks",
                "description": "A machine-parseable list of parent- and student-facing tasks extracted from a school email. Group similar tasks into a single item and use natural language to explain details and consequences.",
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
                                "title": {"type": "string", "description": "Short topic-only label for grouping. Avoid verbs."},
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

    prompt = (
        "You extract actionable school tasks for a busy parent. Output must strictly validate against the provided JSON Schema."
        "You'll be given an email from school."
    )

    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": email_text}
        ],
        response_format={"type": "json_schema", "json_schema": schema}
    )
    # Parse and return the tasks list from the JSON response
    import json
    data = json.loads(resp.choices[0].message.content)
    return data.get("tasks", [])
