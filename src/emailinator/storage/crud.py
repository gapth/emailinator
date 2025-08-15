from .db import SessionLocal, init_db
from .models import Task

init_db()

def add_task(title: str, description: str = "", status: str = "pending"):
    session = SessionLocal()
    task = Task(title=title, description=description, status=status)
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
