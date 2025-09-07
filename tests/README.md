# Tests

This directory contains tests for the Emailinator project.

## Integration Tests

### Inbound Email Tests

The `inbound_email_tests` test the complete inbound email processing pipeline
from email submission to database storage.

#### Prerequisites

The integration tests automatically set the required environment variables and
do not require any manual setup. However, you need to ensure that:

1. **Local Supabase is running**: Start your local Supabase development server
2. **Edge Function environment**: The local Supabase Edge Function needs to be
   running with the following environment variables:

```bash
POSTMARK_BASIC_USER="postmark-basic-user"
POSTMARK_BASIC_PASSWORD="postmark-basic-password"
POSTMARK_ALLOWED_IPS="127.0.0.1"
INBOUND_EMAIL_DOMAIN="in.emailinator.app"
```

These can be set in your `supabase/functions/.env` file (not in Git):

#### Running the Tests

You can run the inbound email integration tests in several ways:

**Option 1: Using Make**

```bash
make test-inbound-email
```

**Option 2: Running with pytest directly**

```bash
source .venv/bin/activate
pytest -s tests/inbound_email_tests.py::TestInboundEmail::test_inbound_email_integration -v
```

**Option 3: Running as a Python script**

```bash
source .venv/bin/activate
python tests/inbound_email_tests.py
```

#### What the Tests Do

The integration test runs the following steps **in sequence**, and stops if any
step fails:

1. **Environment Variable Setup**: Automatically sets all required environment
   variables for the test execution
2. **Database Reset**: Runs `supabase db reset` to ensure a clean local database
   state
3. **Email Processing**: Sends all `.eml` files in `tests/email_data/` to the
   Supabase inbound-email function using the `send_to_supabase` tool

If any step fails, the subsequent steps are not executed.

#### Test Data

The test uses a custom seed file `tests/inbound_email_tests_seed.sql` which
contains setup for a test user, their forward alias, and processing budget of
1c. This seed file is temporarily used during the database reset to ensure
consistent test conditions.

The test uses email files located in `tests/email_data/`. These are real email
files in `.eml` format that represent various types of emails that the system
should be able to process.

#### Output

The tests provide detailed output showing:

- Environment variable setup status
- Database reset status
- Individual email processing results
- Overall success/failure summary

#### Troubleshooting

**Local Supabase Not Running**

```
✗ supabase db reset failed with return code 1
```

Solution: Start your local Supabase development server with `supabase start`.

**Edge Function Environment Variables Not Set**

If emails fail to process, ensure the Edge Function has the required environment
variables set in `supabase/functions/.env.local`.

**Supabase CLI Not Found**

```
✗ Supabase CLI not found. Please install Supabase CLI.
```

Solution: Install the Supabase CLI following the
[official documentation](https://supabase.com/docs/guides/cli).

**Database Reset Timeout**

```
✗ Database reset failed or timed out
```

Solution: Check your Supabase project status and network connection.

**Email Sending Failures**

```
✗ Failed to send example.eml
```

Solution: Check the Supabase function logs and ensure the inbound-email function
is deployed and running.
