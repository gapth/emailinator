import sys
sys.path.append('src')

import pytest

try:
    from fastapi.testclient import TestClient
    from emailinator.service import app
    import emailinator.processing.task_extractor as task_extractor
    import emailinator.processing.task_updater as task_updater
    import emailinator.storage.crud as crud
except ModuleNotFoundError:
    pytest.skip("fastapi not installed", allow_module_level=True)


def test_post_email(monkeypatch):
    def fake_extract(_):
        return [{"title": "Task A"}]

    def fake_update(tasks):
        fake_update.called = True

    fake_update.called = False
    monkeypatch.setattr(task_extractor, "extract_tasks_from_text", fake_extract)
    monkeypatch.setattr(task_updater, "update_tasks_in_db", fake_update)

    client = TestClient(app)
    with open("tests/data/simple_email1.eml", "rb") as f:
        files = {"file": ("email.eml", f, "message/rfc822")}
        response = client.post("/emails", files=files)

    assert response.status_code == 200
    assert response.json()["task_count"] == 1
    assert fake_update.called


def test_post_email_dedup(monkeypatch):
    monkeypatch.setenv("DEDUP_ON_RECEIVE", "1")

    from types import SimpleNamespace

    def fake_list():
        return [SimpleNamespace(title="Existing", description=None, due_date=None,
                                consequence_if_ignore=None, parent_action=None,
                                parent_requirement_level=None, student_action=None,
                                student_requirement_level=None)]

    def fake_extract(email_text, existing):
        fake_extract.called = True
        return [{"title": "Existing"}, {"title": "Task B"}]

    def fake_delete():
        fake_delete.called = True

    def fake_update(tasks):
        fake_update.called_with = tasks

    fake_extract.called = False
    fake_delete.called = False
    fake_update.called_with = None

    monkeypatch.setattr(crud, "list_tasks", fake_list)
    monkeypatch.setattr(task_extractor, "extract_deduplicated_tasks", fake_extract)
    monkeypatch.setattr(crud, "delete_all_tasks", fake_delete)
    monkeypatch.setattr(task_updater, "update_tasks_in_db", fake_update)

    client = TestClient(app)
    with open("tests/data/simple_email1.eml", "rb") as f:
        files = {"file": ("email.eml", f, "message/rfc822")}
        response = client.post("/emails", files=files)

    assert response.status_code == 200
    assert response.json()["task_count"] == 2
    assert fake_extract.called
    assert fake_delete.called
    assert fake_update.called_with == [{"title": "Existing"}, {"title": "Task B"}]


def test_get_tasks():
    from datetime import date

    crud.delete_all_tasks()
    crud.add_task(title="Task A", due_date=date(2024, 9, 1), parent_requirement_level="MANDATORY")
    crud.add_task(title="Task B", parent_requirement_level="OPTIONAL")
    crud.add_task(title="Task C", due_date=date(2024, 9, 2), parent_requirement_level="OPTIONAL")

    client = TestClient(app)
    resp = client.get("/tasks")
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()["tasks"]}
    assert titles == {"Task A", "Task B", "Task C"}

    resp = client.get("/tasks", params={"include_no_due_date": "0"})
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()["tasks"]}
    assert titles == {"Task A", "Task C"}

    resp = client.get("/tasks", params={"due_date_to": "2024-09-01"})
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()["tasks"]}
    assert titles == {"Task A", "Task B"}

    resp = client.get("/tasks", params={"due_date_from": "2024-09-02"})
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()["tasks"]}
    assert titles == {"Task B", "Task C"}

    resp = client.get(
        "/tasks",
        params={
            "due_date_from": "2024-09-01",
            "due_date_to": "2024-09-02",
            "parent_requirement_levels": ["MANDATORY"],
        },
    )
    assert resp.status_code == 200
    titles = {t["title"] for t in resp.json()["tasks"]}
    assert titles == {"Task A"}

    crud.delete_all_tasks()


def test_web_lists_and_updates_tasks():
    from datetime import date

    crud.delete_all_tasks()
    t = crud.add_task(title="Web Task", due_date=date(2024, 9, 1))

    client = TestClient(app)
    resp = client.get("/")
    assert resp.status_code == 200
    assert "Web Task" in resp.text

    resp = client.post(f"/tasks/{t.id}/status", data={"status": "done"})
    assert resp.status_code == 200
    updated = crud.list_tasks()[0]
    assert updated.status == "done"

    crud.delete_all_tasks()


def test_tasks_sorted_by_due_date():
    from datetime import date

    crud.delete_all_tasks()
    crud.add_task(title="Task B", due_date=date(2024, 10, 1))
    crud.add_task(title="Task A", due_date=date(2024, 9, 1))
    crud.add_task(title="Task C")

    client = TestClient(app)
    resp = client.get("/tasks")
    assert resp.status_code == 200
    titles = [t["title"] for t in resp.json()["tasks"]]
    assert titles == ["Task A", "Task B", "Task C"]

    crud.delete_all_tasks()
