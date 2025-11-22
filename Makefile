.DEFAULT_GOAL := help

.PHONY: help install sync clean
.PHONY: format lint typecheck test test-only test-e2e

# =============================================================================
# General development Commands (Unified Environment)
# =============================================================================

format:
	uv run ruff format packages tests

lint:
	uv run ruff check packages tests

typecheck:
	uv run basedpyright packages tests

test-only:
	uv run pytest tests/packages -v

test: format lint typecheck test-only

test-e2e:
	uv run pytest tests/e2e -v

# =============================================================================
# Per-Package development Commands (Pattern Rules)
# =============================================================================

format-%:
	uv run ruff format packages/$* tests/packages/$*

lint-%:
	uv run ruff check packages/$* tests/packages/$*

typecheck-%:
	uv run basedpyright packages/$* tests/packages/$*

test-only-%:
	uv run pytest tests/packages/$* -v

test-%: format-% lint-% typecheck-%
	uv run pytest tests/packages/$* -v

# =============================================================================
# Environments commands (not necessary by default)
# =============================================================================

install:
	uv sync --all-extras

sync:
	uv sync --all-extras

clean:
	rm -rf .venv
	find packages -type d -name .venv -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true

# =============================================================================
# Help
# =============================================================================

help:
	@echo "Available targets:"
	@echo ""
	@echo "General development commands:"
	@echo "  format           - Format all code"
	@echo "  lint             - Lint all code"
	@echo "  typecheck        - Type check all code"
	@echo "  test             - Run all checks and tests"
	@echo "  test-only        - Run only tests"
	@echo "  test-e2e         - Run E2E tests (requires docker-compose up -d)"
	@echo ""
	@echo "Per-package development commands:"
	@echo "  format-<package>     - Format specific package code"
	@echo "  lint-<package>       - Lint specific package code"
	@echo "  typecheck-<package>  - Type check specific package code"
	@echo "  test-<package>       - Run all checks and tests for specific package"
	@echo "  test-only-<package>  - Run only tests for specific package"
	@echo ""
	@echo "Environments commands (not necessary by default):"
	@echo "  install          - Install all dependencies"
	@echo "  sync             - Sync dependencies"
	@echo "  clean            - Remove virtual environments and caches"
