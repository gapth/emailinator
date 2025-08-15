from ..storage import crud

def list_tasks_cli():
    tasks = crud.list_tasks()
    for task in tasks:
        print(f"- [{task.status}] {task.id}: {task.title}")
