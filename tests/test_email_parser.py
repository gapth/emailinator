from emailinator.email_parser import extract_tasks

def test_extract_tasks_mock(monkeypatch):
    def fake_ai(_):
        return ["Task A", "Task B"]

    monkeypatch.setattr("emailinator.email_parser.extract_tasks_with_ai", fake_ai)
    result = extract_tasks("Some email")
    assert result == ["Task A", "Task B"]
