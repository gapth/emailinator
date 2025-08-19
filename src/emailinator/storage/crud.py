from datetime import date
import json

from .db import SessionLocal, init_db
from .models import Task, User


init_db()


def add_task(
    *,
    user: str,
    title: str,
    description: str = None,
    due_date: date = None,  # Accepts Python date object
    consequence_if_ignore: str = None,
    parent_action: str = None,
    parent_requirement_level: str = None,
    student_action: str = None,
    student_requirement_level: str = None,
    status: str = "pending",
):
    session = SessionLocal()
    task = Task(
        user=user,
        title=title,
        description=description,
        due_date=due_date,
        consequence_if_ignore=consequence_if_ignore,
        parent_action=parent_action,
        parent_requirement_level=parent_requirement_level,
        student_action=student_action,
        student_requirement_level=student_requirement_level,
        status=status,
    )
    session.add(task)
    session.commit()
    session.refresh(task)
    session.close()
    return task


def list_tasks(user: str):
    session = SessionLocal()
    tasks = (
        session.query(Task)
        .filter(Task.user == user)
        .order_by(Task.due_date.is_(None), Task.due_date)
        .all()
    )
    session.close()
    return tasks


def delete_all_tasks(user: str | None = None):
    """Remove tasks from the database."""
    session = SessionLocal()
    query = session.query(Task)
    if user is not None:
        query = query.filter(Task.user == user)
    query.delete()
    session.commit()
    session.close()


def update_task(task_id: int, user: str, **kwargs):
    session = SessionLocal()
    task = session.query(Task).filter(Task.id == task_id, Task.user == user).first()
    if not task:
        session.close()
        return None
    for key, value in kwargs.items():
        setattr(task, key, value)
    session.commit()
    session.refresh(task)
    session.close()
    return task


def upsert_user(username: str, api_key: str):
    """Create or update a user with the given API key."""
    session = SessionLocal()
    user = session.get(User, username)
    if user:
        user.api_key = api_key
    else:
        user = User(username=username, api_key=api_key)
        session.add(user)
    session.commit()
    session.close()


def verify_api_key(username: str, api_key: str) -> bool:
    """Return True if the api_key matches the stored value for the user."""
    session = SessionLocal()
    user = (
        session.query(User)
        .filter(User.username == username, User.api_key == api_key)
        .first()
    )
    session.close()
    return user is not None


def get_user_preferences(username: str):
    """Return stored user preferences or defaults."""
    session = SessionLocal()
    user = session.get(User, username)
    prefs = {
        "include_no_due_date": True,
        "parent_requirement_levels": [],
    }
    if user:
        if user.include_no_due_date is not None:
            prefs["include_no_due_date"] = user.include_no_due_date
        if user.parent_requirement_levels:
            prefs["parent_requirement_levels"] = json.loads(
                user.parent_requirement_levels
            )
    session.close()
    return prefs


def update_user_preferences(
    username: str, include_no_due_date: bool, parent_requirement_levels: list[str]
):
    """Update stored user preferences."""
    session = SessionLocal()
    user = session.get(User, username)
    if not user:
        session.close()
        return False
    user.include_no_due_date = include_no_due_date
    user.parent_requirement_levels = json.dumps(parent_requirement_levels)
    session.commit()
    session.close()
    return True

