# Emailinator

Emailinator helps parents manage school emails—and eventually other communications—by focusing on the tasks they need to handle. Users forward messages to the system, which extracts actionable tasks and lets each family decide how involved the assistant should be.

## High-level architecture

- **Supabase** provides the database, server logic, and authentication.
- **OpenAI** performs task extraction.
- **Cloudflare** DNS to point `in.emailinator.app` to **Postmark**, which forwards messages to a **Supabase** webhook for processing.
- **Flutter** powers the web, Android, and iOS apps.
- **Cloudflare** hosts the web experience.

## Development

### Python tests

Install dependencies and run the email parser unit tests:

```bash
pip install -r requirements.txt
pytest
```

### Supabase Edge Function tests

Install JavaScript dependencies and run the Edge Function tests:

```bash
npm install
npm run test:inbound-email
```

### Manual email submission

Use the helper script to post a `.eml` file to the inbound-email Edge Function:

```bash
source .venv/bin/activate
ACCESS_TOKEN=$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | jq -r .access_token)
python -m emailinator.send_to_supabase --file path/to/email.eml --access-token "$ACCESS_TOKEN" --url "$SUPABASE_URL/functions/v1/inbound-email"
```

### Scheduling reprocess-unprocessed

Deploy the function and schedule it to run periodically using Supabase Cron:

```bash
supabase functions deploy reprocess-unprocessed
```

Schedule the reprocess-unprocessed Edge Function to recur on the Supabase dashboard > Integrations > Cron

To test locally:

```bash
curl -i -X POST "$SUPABASE_URL/functions/v1/reprocess-unprocessed" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"  
```

### Depositing monthly OpenAI budget

Deploy the `deposit-budget` Edge Function and schedule it to run regularly (e.g. monthly) with Supabase Cron. Each run deposits a fixed amount of OpenAI API budget into the specified user's account.

Set the deposit amount via the `BUDGET_DEPOSIT_NANO_USD` environment variable.

```
supabase functions deploy deposit-budget
```

Then schedule the function from the Supabase dashboard and invoke it with the service role key.

To test locally:

```bash
curl -i -X POST "$SUPABASE_URL/functions/v1/deposit-budget" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H 'Content-type: application/json' \
  -d "{\"user_id\": \"$USER_ID\"}"
```

### Dumping and repopulating the local database

Export the entire local Supabase database, including `auth.users`, to
`supabase/seed.sql`:

```bash
supabase db dump --local --data-only > supabase/seed.sql
```

To reset the local database and repopulate it with the contents of
`supabase/seed.sql`:

```bash
# This includes seeding data from supabase/seed.sql.
supabase db reset
```
