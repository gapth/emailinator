# Emailinator

Emailinator now relies on Supabase for storage and Edge Functions for task extraction. The legacy Python FastAPI service has been removed.

## Static test page

A simple HTML page for testing Supabase authentication and task listings is available at `index.html`.

Serve it locally with a basic HTTP server:

```bash
SUPABASE_URL=<url> SUPABASE_ANON_KEY=<anon-key> make serve
# or generate env.js yourself and run
python -m http.server --directory src/emailinator/templates 8000
```

Then open [http://localhost:8000](http://localhost:8000) in your browser.
The Makefile writes these values to `env.js` so the page can initialize the Supabase client.

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
  -H "apikey: $ANON_KEY" \                                                          
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | jq -r .access_token)   
python -m emailinator.send_to_supabase --file path/to/email.eml --access-token "$ACCESS_TOKEN" --url "$SUPABASE_URL/functions/v1/inbound-email"
```

