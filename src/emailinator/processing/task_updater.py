from ..storage import crud
from datetime import datetime

def update_tasks_in_db(task_list):
    """Takes a list of dicts and adds them to DB."""
    for task in task_list:
        due_date_str = task.get("due_date")
        due_date = None
        if due_date_str:
            try:
                due_date = datetime.strptime(due_date_str, "%Y-%m-%d").date()
            except ValueError:
                due_date = None

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
