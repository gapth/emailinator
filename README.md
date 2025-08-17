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
