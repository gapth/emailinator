# AI Agent Instructions for Emailinator

## Repository Overview

Emailinator is a multi-platform family communication management system that
helps parents manage school emails by extracting actionable tasks. The system
uses AI-powered task extraction with comprehensive web, mobile, and email
processing capabilities.

**Repository Type:** Multi-language full-stack application\
**Languages:** Python, TypeScript/JavaScript, Dart/Flutter\
**Target Platforms:** Web (Cloudflare), iOS, Android\
**Repository Size:** ~50 files across tools, functions, and mobile app\
**Architecture:** Microservices with Supabase backend, OpenAI integration,
Flutter frontend

### Technology Stack

- **Backend:** Supabase (PostgreSQL, Edge Functions, Auth)
- **AI:** OpenAI API for task extraction
- **Email:** Postmark for inbound email processing
- **Frontend:** Flutter (Web, iOS, Android)
- **Hosting:** Cloudflare Pages (web), App stores (mobile)
- **Build Tools:** Make (Python), npm (TypeScript), Flutter CLI

## Build and Validation Instructions

### Environment Requirements

- **Python:** 3.12+ (confirmed working with 3.12.3)
- **Node.js:** 20+ (confirmed working with 20.19.5, npm 10.8.2)
- **Flutter:** Latest stable (required for mobile/web app development)
- **Supabase CLI:** Latest (optional for local database development)
- **Deno:** 2.x (required for Supabase function development)

### Critical Build System Issue and Workaround

**ISSUE:** The Makefile uses `source` command which fails in sh/dash shells:

```bash
make install  # FAILS with: /bin/sh: 1: source: not found
```

**WORKAROUND:** Always use bash explicitly for Python environment commands:

```bash
# Instead of: make install
bash -c "source .venv/bin/activate && pip install --upgrade pip setuptools wheel && pip install -e . && pip install -r requirements.txt"
```

### Python Development Setup (2-3 minutes)

**Required Steps (ALWAYS run in this order):**

```bash
# 1. Create virtual environment (if not exists)
python3 -m venv .venv

# 2. Install dependencies (use bash explicitly)
bash -c "source .venv/bin/activate && pip install --upgrade pip setuptools wheel && pip install -r requirements.txt"

# 3. Verify installation
bash -c "source .venv/bin/activate && python -c 'import tools; print(\"Python package imports successfully\")'"
```

**Testing Python code:**

```bash
# Run all Python tests (5-10 seconds)
bash -c "source .venv/bin/activate && pytest -s"

# Run specific test file
bash -c "source .venv/bin/activate && pytest -s tools/test_sanitize_emails.py"
```

**Python code formatting:**

```bash
# Check formatting (1-2 seconds)
bash -c "source .venv/bin/activate && black --check tools/ && isort --check-only tools/"

# Apply formatting
bash -c "source .venv/bin/activate && black tools/ && isort tools/"
```

### TypeScript/Supabase Development (1-2 minutes)

**Setup:**

```bash
# Install dependencies (30 seconds)
npm install

# Verify installation
npm list
```

**Testing Supabase Functions:**

```bash
# Run all function tests (15-30 seconds)
npm test

# Run individual function tests
npm run test:inbound-email
npm run test:reprocess-unprocessed  
npm run test:deposit-budget
npm run test:ai-utils

# Run tests in parallel (faster)
npm run test:parallel
```

**TypeScript formatting:**

```bash
# Check formatting
npx prettier --check "supabase/functions/**/*.{js,ts,json}"

# Apply formatting
npm run format
```

### Flutter Development

**Setup (if Flutter SDK available):**

```bash
cd emailinator_flutter
flutter pub get  # Install dependencies
```

**Testing and Building:**

```bash
cd emailinator_flutter

# Analyze code (10-20 seconds)
flutter analyze

# Check formatting
dart format --set-exit-if-changed .

# Run tests (30-60 seconds)
flutter test

# Build for web (2-5 minutes)
flutter build web --release
```

**Running the app:**

```bash
cd emailinator_flutter

# Web (requires .env.local.json)
flutter run -d chrome --dart-define-from-file=.env.local.json

# iOS Simulator (must be started first from Xcode or command line)
flutter run --dart-define-from-file=.env.local.json

# Android (must start Android Emulator from Android Studio first)
flutter run --dart-define-from-file=.env.local.json
```

### Pre-commit Hook Setup

**Installation:**

```bash
# Make hook executable
chmod +x .git/hooks/pre-commit

# Install Python dependencies
bash -c "source .venv/bin/activate && pip install -r requirements.txt"

# Install npm dependencies
npm install

# Test hook
.git/hooks/pre-commit
```

**Manual quality checks:**

```bash
# Run all formatters manually
cd emailinator_flutter && dart format . && cd ..
bash -c "source .venv/bin/activate && black tools/ && isort tools/"
npx prettier --write "supabase/functions/**/*.{js,ts,json}"
```

## Project Architecture and Layout

### Root Directory Structure

```
├── .github/workflows/          # CI/CD pipelines
├── .git/                      # Git metadata
├── emailinator_flutter/       # Flutter mobile/web app
├── supabase/                  # Backend functions and config
├── test_integration/          # Integration tests
├── tools/                     # Python utilities
├── Makefile                   # Python build automation (has shell issues)
├── package.json               # npm scripts for Supabase functions
├── pyproject.toml             # Python project configuration
├── requirements.txt           # Python dependencies
└── README.md                  # Main documentation
```

### Key Source Files

**Main Python Tools:**

- `tools/send_to_supabase.py` - Email submission utility for testing
- `tools/sanitize_emails.py` - Email sanitization utility
- `tools/__init__.py` - Python package initialization

**Supabase Edge Functions:**

- `supabase/functions/inbound-email/` - Main email processing function
- `supabase/functions/reprocess-unprocessed/` - Batch reprocessing function
- `supabase/functions/deposit-budget/` - Budget management function
- `supabase/functions/_shared/` - Shared utilities (AI, task processing)

**Flutter App:**

- `emailinator_flutter/lib/` - Main Flutter application code
- `emailinator_flutter/test/` - Flutter unit tests
- `emailinator_flutter/pubspec.yaml` - Flutter dependencies

### Configuration Files

- `.prettierrc` - JavaScript/TypeScript formatting rules
- `pyproject.toml` - Python project settings (black, isort, pytest config)
- `supabase/config.toml` - Supabase local development configuration
- `emailinator_flutter/analysis_options.yaml` - Flutter/Dart analysis rules

### CI/CD Pipeline (GitHub Actions)

**Main Workflow:** `.github/workflows/deploy.yml`

- **Change Detection:** Uses path-based filtering to run only relevant tests
- **Python Tests:** Runs pytest when Python files change
- **Flutter Tests:** Runs flutter analyze/test when Flutter files change
- **Supabase Tests:** Runs npm test when Supabase files change
- **Deployment:** Auto-deploys to Cloudflare/Supabase on main branch

**Quick Tests:** `.github/workflows/pr-quick-tests.yml`

- **Purpose:** Fast feedback for pull requests
- **Runs:** Flutter analysis, Supabase function tests, basic Python import
  checks
- **Time:** ~2-3 minutes vs ~10-15 minutes for full pipeline

### Dependencies and Hidden Requirements

**Python Package Dependencies:**

- beautifulsoup4, pytest, psycopg2-binary, python-dotenv, requests
- black, isort (code formatting)
- Project configured as installable package via pyproject.toml

**npm Dependencies:**

- tsx (TypeScript execution), prettier (formatting)
- Minimal dependencies by design for serverless functions

**Flutter Dependencies:**

- supabase_flutter, provider, intl, flutter_slidable
- Standard Flutter packages for state management and UI

**Environment Variables Required:**

- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PUBLIC_WEB_BASE_URL` (for Flutter app)
- `POSTMARK_BASIC_USER`, `POSTMARK_BASIC_PASSWORD` (for email processing)
- `OPENAI_API_KEY` (for AI task extraction)

### Time Estimates for Commands

**Fast Operations (< 30 seconds):**

- `npm install` (~30 seconds)
- `npm test` (~15-30 seconds)
- `pytest -s` (~5-10 seconds)
- Code formatting checks (~1-2 seconds)

**Medium Operations (30 seconds - 2 minutes):**

- Python venv setup with dependencies (~2-3 minutes)
- `flutter pub get` (~30-60 seconds)
- `flutter test` (~30-60 seconds)

**Slow Operations (2+ minutes):**

- `flutter build web` (~2-5 minutes)
- Full CI/CD pipeline (~10-15 minutes)
- Supabase local setup with database (~3-5 minutes)

### Validation Pipeline

**Pre-commit Checks:**

1. Flutter analyze and test
2. npm test (all Supabase functions)
3. Code formatting (Dart, Python, TypeScript)

**CI/CD Validation:**

1. Change detection and parallel test execution
2. Full test suites for changed components
3. Automated deployment on successful tests

**Manual Verification Steps:**

```bash
# Verify Python package can be imported
bash -c "source .venv/bin/activate && python -c 'import tools; print(\"OK\")'"

# Verify all formatters pass
npx prettier --check "supabase/functions/**/*.{js,ts,json}"
bash -c "source .venv/bin/activate && black --check tools/ && isort --check-only tools/"

# Verify tests pass
npm test
bash -c "source .venv/bin/activate && pytest -s"
```

## Key Instructions for Coding Agents

1. **ALWAYS use bash -c "source .venv/bin/activate && ..." for Python
   commands** - The Makefile source command fails in sh/dash shells

2. **Install dependencies in correct order:** Python venv → npm → Flutter (if
   available)

3. **Test early and often:** Run tests after any code changes to catch issues
   quickly

4. **Use path-based change detection:** Only run tests for changed components to
   save time

5. **Validate formatting:** Always check code formatting before committing
   changes

6. **Trust these instructions:** Only search for additional information if these
   instructions are incomplete or incorrect

7. **Environment setup is critical:** Ensure Python 3.12+, Node.js 20+, and
   optionally Flutter SDK are available before starting development

This instruction set provides the complete foundation for efficiently working
with the Emailinator codebase, avoiding common pitfalls, and maintaining code
quality standards.
