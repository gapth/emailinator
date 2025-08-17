import asyncio
from contextlib import suppress

from fastapi import FastAPI, UploadFile, File, HTTPException

from .batch import deduplicate_tasks
from .config import load_config
from .input.email_reader import read_email_bytes
from .processing.email_parser import extract_text_from_email
from .processing import task_extractor, task_updater

app = FastAPI()

_dedupe_task = None


async def _run_periodic_dedupe(interval: float):
    while True:
        await asyncio.sleep(interval)
        deduplicate_tasks()


@app.on_event("startup")
async def _startup_event():
    config = load_config()
    interval = config.get("dedupe_interval_seconds", 3600)
    global _dedupe_task
    _dedupe_task = asyncio.create_task(_run_periodic_dedupe(interval))


@app.on_event("shutdown")
async def _shutdown_event():
    if _dedupe_task:
        _dedupe_task.cancel()
        with suppress(asyncio.CancelledError):
            await _dedupe_task


@app.post("/emails")
async def receive_email(file: UploadFile = File(...)):
    """Accept an email file upload and extract tasks from it."""
    data = await file.read()
    try:
        msg = read_email_bytes(data)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid email file")

    text = extract_text_from_email(msg)
    tasks = task_extractor.extract_tasks_from_text(text)
    task_updater.update_tasks_in_db(tasks)
    return {"task_count": len(tasks)}
