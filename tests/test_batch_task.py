import sys
import threading

sys.path.append('src')

import pytest

try:
    from fastapi.testclient import TestClient
    import emailinator.service as service
except ModuleNotFoundError:
    pytest.skip("fastapi not installed", allow_module_level=True)

app = service.app


def test_dedupe_task_runs_periodically(monkeypatch):
    event = threading.Event()

    def fake_dedupe():
        event.set()

    monkeypatch.setattr(service, "deduplicate_tasks", fake_dedupe)
    monkeypatch.setattr(service, "load_config", lambda: {"dedupe_interval_seconds": 0.01})

    with TestClient(app):
        assert event.wait(0.5)
