# Emailinator

A service that extracts tasks from emailed announcements. It exposes a FastAPI endpoint to receive `.eml` files and updates a local SQLite database.

## Installation

Install the Python dependencies before running the service or tests:

```bash
pip install -r requirements.txt
```

## Running the service

Start the service using the Makefile (default target `run`):

```bash
make run
```

`make` without arguments also starts the server. The service listens on the
`HOST` and `PORT` environment variables (default `0.0.0.0:8000`).

## Submitting an email

Use the helper CLI to post a downloaded `.eml` file to the running service:

```bash
python -m emailinator.send_email --file path/to/email.eml
```

You can override the service URL with `--url`.

## Listing tasks

Retrieve stored tasks with a browser or `curl` using the `/tasks` endpoint. All query parameters are optional:

- `due_date_from` and `due_date_to` (`YYYY-MM-DD`) bound the due date range.
- `include_no_due_date` (default `true`) excludes tasks without a due date when set to `false`.
- `parent_requirement_levels` (repeatable) limits results to specific levels.

Omitting a parameter means no filtering on that field.

Example with `curl`:

```bash
curl "http://localhost:8000/tasks?due_date_from=2024-09-01&due_date_to=2024-09-30&parent_requirement_levels=MANDATORY&parent_requirement_levels=OPTIONAL"
```

You can also navigate to a simpler query, e.g.:

```
http://localhost:8000/tasks?due_date_to=2024-09-01
```

The response JSON matches the `tasks_list` format used throughout the project.
