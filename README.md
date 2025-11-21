# Python TDD Workspace

A Python Test-Driven Development workspace using `uv` for dependency management, featuring multiple AWS Lambda functions organized as independent workspaces.


## Setup

1. **Install UV** (if not already installed):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

2. **Sync dependencies**:
   ```bash
   uv sync
   ```

## Running Tests

### Run all tests (from root):
```bash
make test
```

### Run tests for a specific workspace:

```bash
uv run --directory workspaces/adder_workspace pytest
uv run --directory workspaces/multiplier_workspace pytest
```

## Code Quality

### Linting
```bash
make lint
```

### Typecheck
```bash
make typecheck
```

### Auto-fix linting issues
```bash
uv run ruff check . --fix
```

### Formatting
```bash
make format
```

## Ruff Configuration

The project uses Ruff with the following rules enabled:
- **E, W**: pycodestyle errors and warnings
- **F**: Pyflakes (logical errors)
- **I**: isort (import sorting)
- **C**: Complexity and comprehensions
- **B**: flake8-bugbear (likely bugs)
- **N**: pep8-naming (naming conventions)
- **ANN**: flake8-annotations (type hints enforcement)

## Workspace Structure

Each workspace is an independent Python package with:
- **src/**: Source code organized as a Python package
- **tests/**: Test files using pytest
- **Dockerfile**: Lambda-compatible container configuration
- **pyproject.toml**: Package metadata and dependencies

## Adding a New Workspace

1. Create a new directory under `workspaces/`:
   ```bash
   mkdir -p workspaces/new_lambda_workspace/src/new_lambda
   mkdir -p workspaces/new_lambda_workspace/tests
   ```

2. Create `pyproject.toml`:
   ```toml
   [project]
   name = "new-lambda"
   version = "0.1.0"
   description = "New Lambda"
   requires-python = ">=3.12"
   dependencies = []

   [build-system]
   requires = ["hatchling"]
   build-backend = "hatchling.build"

   [tool.hatch.build.targets.wheel]
   packages = ["src/new_lambda"]
   ```

3. Add to root workspace in `pyproject.toml`:
   ```toml
   dependencies = [
       "adder",
       "multiplier",
       "new-lambda",  # Add this
   ]

   [tool.uv.sources]
   new-lambda = { workspace = true }
   ```

4. Run `uv sync` to install the new workspace

## Docker Deployment

Each workspace can be built and deployed independently:

```bash
cd workspaces/adder_workspace
docker build -t adder-lambda .
docker run -p 9000:8080 adder-lambda
```

Test the Lambda locally:
```bash
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"a": 5, "b": 3}'
```
