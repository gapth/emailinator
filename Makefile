PYTHON := python3
VENV := .venv
ACTIVATE := source $(VENV)/bin/activate

# Default target: setup & run
default: run

.PHONY: venv install run test clean

# Create virtual environment if it doesn't exist
venv:
	@if [ ! -d "$(VENV)" ]; then \
		$(PYTHON) -m venv $(VENV); \
		echo "Virtual environment created in $(VENV)"; \
	fi

# Install dependencies (and project in editable mode)
install: venv
	$(ACTIVATE) && pip install --upgrade pip setuptools wheel
	$(ACTIVATE) && pip install -e .
	$(ACTIVATE) && pip install -r requirements.txt

# Run the main program
run: install
	$(ACTIVATE) && python -m emailinator.main

# Run tests with pytest
test: install
	$(ACTIVATE) && pytest

# Remove virtual environment and cache files
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +
