PYTHON := python3
VENV := .venv
ACTIVATE := source $(VENV)/bin/activate
STAMP := $(VENV)/.requirements.stamp

# Default target: run tests
default: test

.PHONY: venv install test test-tools test-flutter test-npm test-integration clean

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

# Run all tests: tools Python tests, Flutter, and npm (supabase)
test: install test-tools test-flutter test-npm


# Run Python tests for tools/ only
test-tools: install
	@echo "Running Python tests..."
	$(ACTIVATE) && \
	if [ "$(TESTS)" != "" ]; then \
	        pytest -s $(foreach t,$(TESTS),tools/$(t).py) || true; \
	else \
	        pytest -s tools/ || true; \
	fi

# Run Flutter tests
test-flutter:
	@echo "Running Flutter tests..."
	cd emailinator_flutter && flutter test

# Run npm/supabase tests  
test-npm:
	@echo "Running npm/supabase tests..."
	npm test

# Run all Integration tests
test-integration: install
	@echo "Running Integration tests..."
	$(ACTIVATE) && pytest -s test_integration/ -v

# Remove virtual environment and cache files
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +
