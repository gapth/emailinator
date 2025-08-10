from .email_parser import extract_tasks

if __name__ == "__main__":
    sample_email = """
    Hello parents, please remember:
    1. Submit the permission slip by Friday.
    2. Bring snacks for the field trip.
    """
    tasks = extract_tasks(sample_email)
    print("Extracted Tasks:")
    for t in tasks:
        print("-", t)
