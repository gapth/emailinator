from ..storage import crud

def update_tasks_in_db(task_list):
    """Takes a list of dicts and adds them to DB."""
    for task in task_list:
        crud.add_task(task["title"], task.get("description", ""))
