from .db import SessionLocal, init_db
from .models import Task
from datetime import date

init_db()

def add_task(
    title: str,
    description: str = None,
    due_date: date = None,  # Accepts Python date object
    consequence_if_ignore: str = None,
    parent_action: str = None,
    parent_requirement_level: str = None,
    student_action: str = None,
    student_requirement_level: str = None,
    status: str = "pending"
):
    session = SessionLocal()
    task = Task(
        title=title,
        description=description,
        due_date=due_date,
        consequence_if_ignore=consequence_if_ignore,
        parent_action=parent_action,
        parent_requirement_level=parent_requirement_level,
        student_action=student_action,
        student_requirement_level=student_requirement_level,
        status=status
    )
    session.add(task)
    session.commit()
    session.refresh(task)
    session.close()
    return task

def list_tasks():
    session = SessionLocal()
    tasks = session.query(Task).all()
    session.close()
    return tasks


def delete_all_tasks():
    """Remove all tasks from the database."""
    session = SessionLocal()
    session.query(Task).delete()
    session.commit()
    session.close()

def update_task(task_id: int, **kwargs):
    session = SessionLocal()
    task = session.query(Task).get(task_id)
    if not task:
        session.close()
        return None
    for key, value in kwargs.items():
        setattr(task, key, value)
    session.commit()
    session.refresh(task)
    session.close()
    return task
