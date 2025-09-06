# Emailinator Tools

This directory contains Python utilities and scripts that support the
Emailinator project.

## Contents

- `send_to_supabase.py` - Script to submit `.eml` files to the Supabase
  inbound-email Edge Function for testing and development

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

## Development

This package can be installed in development mode with:

```bash
pip install -e .
```

The tools are structured as a proper Python package to enable importing and
testing.
