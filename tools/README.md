# Emailinator Tools

This directory contains Python utilities and scripts that support the
Emailinator project.

## Contents

- `send_to_supabase.py` - Script to submit `.eml` files to the Supabase
  inbound-email Edge Function for testing and development
- `sanitize_emails.py` - Script to sanitize `.eml` files by replacing sensitive
  information with safe placeholder values

## Usage

Make sure you have the project dependencies installed:

```bash
make install
```

### send_to_supabase.py

Submit an email file to the local Supabase inbound-email function:

```bash
source supabase/functions/.env.local # File not in Git, contains various env
source .venv/bin/activate
EML_FILE= # Fill in
python -m tools.send_to_supabase --file "$EML_FILE" --url "$SUPABASE_URL/functions/v1/inbound-email" --alias "$ALIAS"
```

Required environment variables:

- `POSTMARK_BASIC_USER` - Basic auth username for the Supabase function
- `POSTMARK_BASIC_PASSWORD` - Basic auth password for the Supabase function
- `POSTMARK_ALLOWED_IPS` - Comma-separated list of IPs of email submitter
- `INBOUND_EMAIL_DOMAIN` - Domain name for inbound email
- `SUPABASE_URL` = For local server, use http://127.0.0.1:54321

### sanitize_emails.py

Sanitize `.eml` files by replacing sensitive information with safe placeholder
values.

The script performs the following sanitization:

1. Keeps only specific headers: From, To, Bcc, Subject, Date, Message-Id
2. Keeps only content with text/plain and text/html Content-Type
3. Replaces all email addresses with "someone@somewhere.com"
4. Replaces all HTTP and HTTPS links with "https://a_link"
5. Replaces blocked words with random animal words (cat, mouse, dog, cow, pig,
   chicken)

```bash
# Basic usage - sanitize all .eml files in a directory
python tools/sanitize_emails.py --dir path/to/email/directory

# Sanitize emails and replace specific words
python tools/sanitize_emails.py --dir manual_eval/emails --block-words password,secret,confidential
```

**Arguments:**

- `--dir` (required): Path to directory containing `.eml` files to sanitize
- `--block-words` (optional): Comma-separated list of words to replace with
  random animal words

**Note:** The script modifies files in-place, so make sure to backup your
original files if needed. Word matching is case-insensitive and uses word
boundaries to match whole words only.

## Development

This package can be installed in development mode with:

```bash
pip install -e .
```

The tools are structured as a proper Python package to enable importing and
testing.
