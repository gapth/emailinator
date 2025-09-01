# Git Pre-commit Hook Setup

This project uses a git pre-commit hook to ensure code quality and consistency
across all file types.

## What the Pre-commit Hook Does

The pre-commit hook automatically runs the following checks before each commit:

1. **Flutter Analyze** - Checks Flutter/Dart code for issues
2. **Flutter Test** - Runs all Flutter unit tests
3. **npm test** - Runs all JavaScript/TypeScript tests
4. **Format All Files** - Formats code in all supported languages:
   - **Dart files** using `dart format`
   - **Python files** using `black` and `isort`
   - **JavaScript/TypeScript files** using `prettier`

## Setup

The hook is already installed at `.git/hooks/pre-commit` and is executable. If
you need to reinstall it:

```bash
# Make sure the hook is executable
chmod +x .git/hooks/pre-commit

# Install Python formatting dependencies
make install

# Install npm dependencies including prettier
npm install
```

## Dependencies

### Required Tools

- **Flutter SDK** - for Dart analysis and testing
- **Node.js/npm** - for JavaScript/TypeScript testing and formatting
- **Python 3.12+** - for Python testing and formatting

### Python Dependencies

- `black` - Python code formatter
- `isort` - Python import sorter

### npm Dependencies

- `prettier` - JavaScript/TypeScript formatter

## How It Works

1. When you run `git commit`, the hook automatically executes
2. If any check fails, the commit is aborted
3. If files are reformatted, you'll need to stage the changes and commit again
4. The hook provides colored output showing the status of each check

## Manual Commands

You can run the individual commands manually:

```bash
# Flutter checks
cd emailinator_flutter
flutter analyze
flutter test
cd ..

# npm tests
npm test

# Formatting
cd emailinator_flutter && dart format . && cd ..  # Dart
source .venv/bin/activate && black src/ && isort src/ && deactivate  # Python
npx prettier --write "supabase/functions/**/*.{js,ts,json}"  # JS/TS
```

## Troubleshooting

### Hook Not Running

- Ensure the hook is executable: `chmod +x .git/hooks/pre-commit`
- Check that you're in the correct repository directory

### Missing Dependencies

- **Flutter not found**: Install Flutter SDK and add to PATH
- **npm not found**: Install Node.js
- **Python formatting tools missing**: Run `make install`

### Test Failures

- Fix the failing tests before committing
- Use `--no-verify` flag to bypass hooks temporarily (not recommended):
  ```bash
  git commit --no-verify -m "commit message"
  ```

### Files Keep Getting Reformatted

- This is normal on first setup - the formatters are applying consistent styling
- Stage the formatted files and commit again:
  ```bash
  git add .
  git commit --amend --no-edit
  ```

## Configuration

### Python Formatting

Configuration is in `pyproject.toml`:

- `[tool.black]` - Black formatter settings
- `[tool.isort]` - Import sorting settings

### JavaScript/TypeScript Formatting

Configuration is in `.prettierrc`:

- Standard Prettier settings for consistent JS/TS formatting

### Dart Formatting

Uses default `dart format` settings (follows official Dart style guide)
