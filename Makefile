# =============================================================================
# UV Workspaces - Makefile for AWS Lambda Functions
# =============================================================================

# Set default target (runs when you type just 'make')
.DEFAULT_GOAL := help

.PHONY: help install sync clean
.PHONY: format lint typecheck test test-only test-e2e

# =============================================================================
# Development Commands (Unified Environment)
# =============================================================================

format:
	uv run ruff format lambdas tests

lint:
	uv run ruff check lambdas tests

typecheck:
	uv run basedpyright lambdas tests

test-only:
	uv run pytest tests/lambdas -v

test: format lint typecheck test-only

test-e2e:
	uv run pytest tests/e2e -v

# =============================================================================
# Per-Lambda Commands (Pattern Rules)
# =============================================================================

# Format specific lambda
format-%:
	uv run ruff format lambdas/$* tests/lambdas/$*

# Lint specific lambda
lint-%:
	uv run ruff check lambdas/$* tests/lambdas/$*

# Type check specific lambda
typecheck-%:
	uv run basedpyright lambdas/$* tests/lambdas/$*

# Test specific lambda without checks
test-only-%:
	uv run pytest tests/lambdas/$* -v

# Test specific lambda with all checks
test-%: format-% lint-% typecheck-%
	uv run pytest tests/lambdas/$* -v

# =============================================================================
# Explicit Setup (not necessary by default)
# =============================================================================

install:
	uv sync --all-extras

sync:
	uv sync --all-extras

clean:
	rm -rf .venv
	find lambdas -type d -name .venv -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Available targets:"
	@echo ""
	@echo "Development commands:"
	@echo "  format           - Format all code"
	@echo "  lint             - Lint all code"
	@echo "  typecheck        - Type check all code"
	@echo "  test             - Run all checks and tests"
	@echo "  test-only        - Run all unit tests"
	@echo "  test-e2e         - Run E2E tests (requires docker-compose up -d)"
	@echo ""
	@echo "Per-lambda commands:"
	@echo "  format-<lambda>     - Format lambda code"
	@echo "  lint-<lambda>       - Lint lambda code"
	@echo "  typecheck-<lambda>  - Type check lambda code"
	@echo "  test-<lambda>       - Run all checks and tests for lambda"
	@echo "  test-only-<lambda>  - Run unit tests for lambda only"
	@echo ""
	@echo "Examples:"
	@echo "  make test-adder"
	@echo "  make test-only-multiplier"
	@echo "  make lint-multiplier"
	@echo ""
	@echo "Explicit Setup (not necessary by default):"
	@echo "  install          - Install all dependencies"
	@echo "  sync             - Sync dependencies"
	@echo "  clean            - Remove virtual environments and caches"
