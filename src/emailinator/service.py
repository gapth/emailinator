import os
import logging
from fastapi import FastAPI, UploadFile, File, HTTPException

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
