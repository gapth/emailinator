from ..storage import crud
from datetime import datetime
from fuzzywuzzy import fuzz

def is_duplicate(new_task, existing_tasks, threshold=50):
    new_title = new_task.get("title", "").lower()
    for task in existing_tasks:
        existing_title = (task.title or "").lower()
        score = fuzz.ratio(new_title, existing_title)
        if score >= threshold:
            return True
    return False

def update_tasks_in_db(task_list):
    """Takes a list of dicts and adds them to DB, deduplicating by fuzzy title match."""
    existing_tasks = crud.list_tasks()
    for task in task_list:
        due_date_str = task.get("due_date")
        due_date = None
        if due_date_str:
            try:
                due_date = datetime.strptime(due_date_str, "%Y-%m-%d").date()
            except ValueError:
                due_date = None

        # Deduplicate using fuzzy title matching
        if is_duplicate(task, existing_tasks):
            continue

        crud.add_task(
            title=task.get("title"),
            description=task.get("description"),
            due_date=due_date,
            consequence_if_ignore=task.get("consequence_if_ignore"),
            parent_action=task.get("parent_action"),
            parent_requirement_level=task.get("parent_requirement_level"),
            student_action=task.get("student_action"),
            student_requirement_level=task.get("student_requirement_level"),
            status=task.get("status", "pending")
        )
