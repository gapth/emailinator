import argparse
import requests


def main():
    parser = argparse.ArgumentParser(description="Submit an email file to the Emailinator service")
    parser.add_argument("--file", required=True, help="Path to .eml file")
    parser.add_argument("--url", default="http://localhost:8000/emails", help="Service endpoint URL")
    args = parser.parse_args()

    with open(args.file, "rb") as f:
        files = {"file": (args.file, f, "message/rfc822")}
        resp = requests.post(args.url, files=files)

    print(f"Status: {resp.status_code}")
    try:
        print(resp.json())
    except Exception:
        print(resp.text)


if __name__ == "__main__":
    main()
