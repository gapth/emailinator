from fastapi import FastAPI, UploadFile, File, HTTPException

from .input.email_reader import read_email_bytes
from .processing.email_parser import extract_text_from_email
from .processing.task_extractor import extract_tasks_from_text
from .processing.task_updater import update_tasks_in_db

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
    tasks = extract_tasks_from_text(text)
    update_tasks_in_db(tasks)
    return {"task_count": len(tasks)}
