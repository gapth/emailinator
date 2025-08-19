from ..storage import crud


def mark_task_done(task_id: int):
    return crud.update_task(task_id, status="done")


def snooze_task(task_id: int):
    return crud.update_task(task_id, status="snoozed")
