import os
import logging
from datetime import date
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, HTTPException, Query

from .input.email_reader import read_email_bytes
from .processing.email_parser import extract_text_from_email
from .processing import task_extractor, task_updater
from .storage import crud

app = FastAPI()


@app.post("/emails")
async def receive_email(file: UploadFile = File(...)):
    """Accept an email file upload and extract tasks from it."""
    data = await file.read()
    try:
        msg = read_email_bytes(data)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid email file")

    text = extract_text_from_email(msg)

    dedup_on_receive = os.getenv("DEDUP_ON_RECEIVE", "0").lower() in {"1", "true", "yes"}
    logger = logging.getLogger("emailinator")
    if dedup_on_receive:
        logger.info("Deduplicating tasks on receive (DEDUP_ON_RECEIVE is enabled)")
        existing_models = crud.list_tasks()
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
        crud.delete_all_tasks()
    else:
        tasks = task_extractor.extract_tasks_from_text(text)

    task_updater.update_tasks_in_db(tasks)
    return {"task_count": len(tasks)}


@app.get("/tasks")
def list_tasks(
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
        raise HTTPException(status_code=400, detail="due_date_from must be before due_date_to")

    all_tasks = crud.list_tasks()
    filtered = []
    for t in all_tasks:
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

        task_dict = {"title": t.title}
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
