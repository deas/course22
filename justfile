# Default command, shows help
default: help

# Show this help message
help:
    @just --list

# Install dependencies
#install:
#    uv pip install -r .devcontainer/requirements.txt
#    # @uv pip install --upgrade pip
#    # @uv pip install -e .

# Install for development
# install-dev: install
#     @uv pip install -e ".[dev]"

# uv sync - not install
sync:
  @uv sync

# Delete all temporary files
# clean:
#     @rm -rf .ipynb_checkpoints
#     @rm -rf .pytest_cache
#     @rm -rf __pycache__
#     @rm -rf build
#     @rm -rf dist
#     @find . -type d -name "__pycache__" -exec rm -rf {} +
#     @find . -type d -name ".pytest_cache" -exec rm -rf {} +

# Run checks using ruff
# check:
#     python -m ruff check .
#     python -m ruff format --check .

# Format files using ruff
format:
    python -m ruff check . --fix
    python -m ruff format .

# Run tests
# #test test_params='tests':
#     @echo "TEST_PARAMS={{test_params}}"
#     python -m pytest --cov=src/autoweb --cov-report xml --disable-pytest-warnings {{test_params}}

# Run all preflight checks
# preflight: check test

# Run the web server
# serve:
#    python -m autoweb.main serve

# Start jupyter lab (JUPYTER_TOKEN from .env authenticates both the UI and the MCP server)
start-jupyter:
    @test -n "$JUPYTER_TOKEN" || { echo "JUPYTER_TOKEN is unset - add it to .env (see README)"; exit 1; }
    uv run jupyter lab --ip=0.0.0.0

# # Pin dependencies
# pin-deps:
#     pip-compile --generate-hashes --output-file=requirements.txt pyproject.toml
#     pip-compile --generate-hashes --extra=dev --output-file=requirements-dev.txt pyproject.toml
