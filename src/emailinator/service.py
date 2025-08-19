import os
import logging
from datetime import date, timedelta
from typing import List, Optional
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Request, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from .input.email_reader import read_email_bytes
from .processing.email_parser import extract_text_from_email
from .processing import task_extractor, task_updater
from .storage import crud
from .auth import auth_backend

app = FastAPI()
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


@app.post("/emails")
async def receive_email(
    user: str = Form(...), api_key: str = Form(...), file: UploadFile = File(...)
):
    """Accept an email file upload and extract tasks from it."""
    data = await file.read()
    try:
        msg = read_email_bytes(data)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid email file")

    text = extract_text_from_email(msg)

    _authenticate(user, api_key)

    dedup_on_receive = os.getenv("DEDUP_ON_RECEIVE", "0").lower() in {
        "1",
        "true",
        "yes",
    }
    logger = logging.getLogger("emailinator")
    if dedup_on_receive:
        logger.info("Deduplicating tasks on receive (DEDUP_ON_RECEIVE is enabled)")
        existing_models = crud.list_tasks(user)
        existing = [
            {
                "title": t.title,
                "description": t.description,
                "due_date": t.due_date.isoformat() if t.due_date else None,
                "consequence_if_ignore": t.consequence_if_ignore,
                "parent_action": t.parent_action,
                "parent_requirement_level": t.parent_requirement_level,
                "student_action": t.student_action,
                "student_requirement_level": t.student_requirement_level,
            }
            for t in existing_models
        ]
        tasks = task_extractor.extract_deduplicated_tasks(text, existing)
        crud.delete_all_tasks(user)
    else:
        tasks = task_extractor.extract_tasks_from_text(text)

    task_updater.update_tasks_in_db(tasks, user)
    return {"task_count": len(tasks)}


@app.get("/tasks")
def list_tasks(
    user: str = Query(...),
    api_key: str = Query(...),
    due_date_from: Optional[date] = Query(None),
    due_date_to: Optional[date] = Query(None),
    include_no_due_date: bool = True,
    parent_requirement_levels: Optional[List[str]] = Query(None),
):
    """Return tasks filtered by due date range and parent requirement level."""
    if (
        due_date_from is not None
        and due_date_to is not None
        and due_date_from > due_date_to
    ):
        raise HTTPException(
            status_code=400, detail="due_date_from must be before due_date_to"
        )

    _authenticate(user, api_key)

    all_tasks = crud.list_tasks(user)
    filtered_models = _filter_tasks(
        all_tasks,
        due_date_from,
        due_date_to,
        include_no_due_date,
        parent_requirement_levels,
    )
    filtered = []
    for t in filtered_models:
        task_dict = {"id": t.id, "title": t.title, "status": t.status}
        if t.description:
            task_dict["description"] = t.description
        if t.due_date:
            task_dict["due_date"] = t.due_date.isoformat()
        if t.consequence_if_ignore:
            task_dict["consequence_if_ignore"] = t.consequence_if_ignore
        if t.parent_action:
            task_dict["parent_action"] = t.parent_action
        if t.parent_requirement_level:
            task_dict["parent_requirement_level"] = t.parent_requirement_level
        if t.student_action:
            task_dict["student_action"] = t.student_action
        if t.student_requirement_level:
            task_dict["student_requirement_level"] = t.student_requirement_level
        filtered.append(task_dict)

    return {"tasks": filtered}


def _filter_tasks(
    tasks,
    due_date_from: Optional[date],
    due_date_to: Optional[date],
    include_no_due_date: bool,
    parent_requirement_levels: Optional[List[str]],
):
    filtered = []
    for t in tasks:
        if (
            parent_requirement_levels is not None
            and t.parent_requirement_level not in parent_requirement_levels
        ):
            continue

        if t.due_date is None:
            if not include_no_due_date:
                continue
        else:
            if due_date_from is not None and t.due_date < due_date_from:
                continue
            if due_date_to is not None and t.due_date > due_date_to:
                continue

        filtered.append(t)

    return filtered


@app.get("/")
def index(
    request: Request,
    user: str = Query(...),
    api_key: str = Query(...),
    due_date_from: Optional[date] = Query(None),
    due_date_to: Optional[date] = Query(None),
    include_no_due_date: Optional[bool] = None,
    parent_requirement_levels: Optional[List[str]] = Query(None),
):
    _authenticate(user, api_key)
    prefs = crud.get_user_preferences(user)
    if include_no_due_date is None:
        include_no_due_date = prefs["include_no_due_date"]
    if parent_requirement_levels is None:
        parent_requirement_levels = prefs["parent_requirement_levels"]
    levels_filter = parent_requirement_levels if parent_requirement_levels else None

    if (due_date_from is None) != (due_date_to is None):
        due_date_from = None
        due_date_to = None

    if due_date_from is None and due_date_to is None:
        today = date.today()
        due_date_from = today
        due_date_to = today + timedelta(days=7)

    all_tasks = crud.list_tasks(user)
    pending = [t for t in all_tasks if t.status == "pending"]
    tasks = _filter_tasks(
        pending,
        due_date_from,
        due_date_to,
        include_no_due_date,
        levels_filter,
    )

    context = {
        "request": request,
        "tasks": tasks,
        "due_date_from": due_date_from.isoformat() if due_date_from else "",
        "due_date_to": due_date_to.isoformat() if due_date_to else "",
        "parent_requirement_levels": parent_requirement_levels or [],
        "include_no_due_date": include_no_due_date,
        "user": user,
        "api_key": api_key,
    }
    return templates.TemplateResponse("index.html", context)


@app.post("/user/preferences")
def set_preferences(
    user: str = Query(...),
    api_key: str = Query(...),
    include_no_due_date: int = Form(...),
    parent_requirement_levels: List[str] = Form([]),
):
    """Update stored user preferences."""
    _authenticate(user, api_key)
    crud.update_user_preferences(
        user, bool(include_no_due_date), parent_requirement_levels
    )
    return {"status": "ok"}


@app.post("/tasks/{task_id}/status")
def update_task_status(
    task_id: int,
    user: str = Query(...),
    api_key: str = Query(...),
    status: str = Form(...),
):
    _authenticate(user, api_key)

    task = crud.update_task(task_id, user, status=status)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return HTMLResponse("")


def _authenticate(user: str, api_key: str):
    if not auth_backend.authenticate(user, api_key):
        raise HTTPException(status_code=401, detail="Invalid credentials")
