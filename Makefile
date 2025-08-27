PYTHON := python3
VENV := .venv
ACTIVATE := source $(VENV)/bin/activate
STAMP := $(VENV)/.requirements.stamp

# Default target: run tests
default: test

.PHONY: venv install test clean

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

install: venv $(STAMP)

# Run tests with pytest
test: install
	$(ACTIVATE) && \
	if [ "$(TESTS)" != "" ]; then \
	        pytest -s $(foreach t,$(TESTS),tests/$(t).py); \
	else \
	        pytest -s; \
	fi
# Remove virtual environment and cache files
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +
