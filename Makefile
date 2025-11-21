.PHONY: format lint typecheck test check

format:
	uv run ruff format .

lint:
	uv run ruff check .

typecheck:
	uv run basedpyright .

test:
	uv run pytest

check: format lint typecheck test
