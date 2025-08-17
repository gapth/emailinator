import sys
sys.path.append('src')

import pytest

try:
    from fastapi.testclient import TestClient
    from emailinator.service import app
    import emailinator.processing.task_extractor as task_extractor
    import emailinator.processing.task_updater as task_updater
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
