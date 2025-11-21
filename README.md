# Python TDD Workspace

A Python Test-Driven Development workspace using `uv` for dependency management, featuring multiple AWS Lambda functions organized as independent workspaces.

## Project Structure

```
python-tdd/
├── workspaces/
│   ├── adder_workspace/
│   │   ├── src/adder/
│   │   │   ├── __init__.py
│   │   │   └── main.py
│   │   ├── tests/
│   │   │   └── test_adder.py
│   │   ├── Dockerfile
│   │   └── pyproject.toml
│   └── multiplier_workspace/
│       ├── src/multiplier/
│       │   ├── __init__.py
│       │   └── main.py
│       ├── tests/
│       │   └── test_multiplier.py
│       ├── Dockerfile
│       └── pyproject.toml
├── pyproject.toml (root workspace configuration)
└── README.md
```

## Features

- **UV Workspace**: Multiple Lambda functions managed as independent workspaces
- **Test-Driven Development**: Comprehensive test coverage with pytest
- **Type Safety**: Full type hints enforced with Ruff's `flake8-annotations`
- **Code Quality**: Ruff for linting and formatting
- **Docker Support**: Each Lambda has its own Dockerfile for containerization
- **AWS Lambda Ready**: Configured for AWS Lambda deployment

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
uv run pytest
```

### Run tests for a specific workspace:

**Option 1: Using --directory flag (from root)**
```bash
uv run --directory workspaces/adder_workspace pytest
uv run --directory workspaces/multiplier_workspace pytest
```

**Option 2: Change directory**
```bash
cd workspaces/adder_workspace
uv run pytest
```

**Option 3: Target specific test directory**
```bash
uv run pytest workspaces/adder_workspace/tests/
```

## Code Quality

### Linting
```bash
uv run ruff check .
```

### Auto-fix linting issues
```bash
uv run ruff check . --fix
```

### Formatting
```bash
uv run ruff format .
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
