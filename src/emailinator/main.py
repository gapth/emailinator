import argparse
from .input.email_reader import read_email_file
from .processing.email_parser import extract_text_from_email
from .processing.task_extractor import extract_tasks_from_text
from .processing.task_updater import update_tasks_in_db
from .output.cli import list_tasks_cli

def main():
    parser = argparse.ArgumentParser(description="Emailinator CLI")
    parser.add_argument("--input", required=True, help="Path to .eml file")
    args = parser.parse_args()

    msg = read_email_file(args.input)
    text = extract_text_from_email(msg)
    tasks = extract_tasks_from_text(text)
    update_tasks_in_db(tasks)
    list_tasks_cli()

if __name__ == "__main__":
    main()
