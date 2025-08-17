PYTHON := python3
VENV := .venv
ACTIVATE := source $(VENV)/bin/activate
DB := tasks.db
STAMP := $(VENV)/.requirements.stamp

# Default target: setup & run
default: run

.PHONY: venv install run test clean dbshell

# Create virtual environment if it doesn't exist
venv:
	@if [ ! -d "$(VENV)" ]; then \
		$(PYTHON) -m venv $(VENV); \
		echo "Virtual environment created in $(VENV)"; \
	fi

# Install dependencies only if requirements.txt changes
$(STAMP): requirements.txt | $(VENV)/bin/activate
	$(ACTIVATE) && pip install --upgrade pip setuptools wheel
	$(ACTIVATE) && pip install -e .
	$(ACTIVATE) && pip install -r requirements.txt
	touch $(STAMP)

install: $(STAMP)

# Run the main program
run: install
	@if [ -z "$(INPUT)" ]; then \
		echo "Error: Please provide INPUT=<file.eml>"; \
		exit 1; \
	fi
	$(ACTIVATE) && python -m emailinator.main --input "$(INPUT)"

# Run tests with pytest
test: install
	$(ACTIVATE) && pytest

# Inspect the database
dbshell:
	@if [ -f $(DB) ]; then \
		sqlite3 $(DB); \
	else \
		echo "Database file '$(DB)' not found."; \
	fi
# Remove virtual environment and cache files
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +
