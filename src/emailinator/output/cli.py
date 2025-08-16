from ..storage import crud

def list_tasks_cli():
    tasks = crud.list_tasks()
    for task in tasks:
        print(f"""
- [{task.status}] {task.id}: {task.title}
  Description: {task.description}
  Due Date: {task.due_date}
  Consequence if Ignored: {task.consequence_if_ignore}
  Parent Action: {task.parent_action}
  Parent Requirement Level: {task.parent_requirement_level}
  Student Action: {task.student_action}
  Student Requirement Level: {task.student_requirement_level}
""")
