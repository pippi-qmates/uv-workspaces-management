# AWS Lambda Functions Collection

A Python project using **UV Workspaces** for dependency management, featuring multiple AWS Lambda functions with **isolated environments for Docker builds** and a **unified environment for development**.

> **📚 Documentation**: The [`docs/`](docs/) folder contains detailed documents explaining the architectural decisions and implementation choices.

## Prerequisites

- [UV](https://docs.astral.sh/uv/getting-started/installation/) installed
- [Make](https://www.gnu.org/software/make/) installed

## Quick Start

1. Run tests: `make test`
2. Open your preferred IDE

**That's it!** UV automatically creates and syncs the environment when needed.

### How It Works

**For Development (IDE)**
- Uses `.venv` with **all** dependencies (including dev tools)
- No import errors, full autocomplete
- All lambdas available for IDE navigation
- Just works

**For Production (Docker)**
- Each lambda exports only its own dependencies
- `make test-adder` tests with adder's isolated dependencies
- `make test-multiplier` tests with multiplier's isolated dependencies
- Minimal Docker images guaranteed

---

## Running Tests

### Full validation (recommended before commit):
```bash
make test
# Runs: format + lint + typecheck + pytest (all Lambdas)
```

### Quick test iteration:
```bash
make test-only
# Just runs pytest for all Lambdas
```

### Test specific Lambda with isolation:
```bash
make test-adder        # Full validation for adder
make test-only-adder   # Just pytest for adder

make test-multiplier        # Full validation for multiplier
make test-only-multiplier   # Just pytest for multiplier
```

### End-to-End tests:
```bash
# 1. Start the services
docker-compose up -d
# 2. Run E2E tests (tests actual Docker containers)
make test-e2e
# 3. Stop the services
docker-compose down
```

**What E2E tests do**:
- Test each Lambda in isolation (adder and multiplier separately)
- Test workflow orchestration (adder → multiplier pipeline)
- Verify containers work exactly like they will in production

**Note**: E2E tests require Docker Compose to be running.

---

## Code Quality

Linting, formatting and type checking are performed automatically during the test commands.

### Type Checking
```bash
make typecheck
```

### Linting
```bash
make lint
```

### Formatting
```bash
make format
```

---

## Docker Build

### Build individual Lambda images
```bash
make docker-adder
make docker-multiplier
```

Or manually:
```bash
docker build -f docker/lambda.Dockerfile --build-arg LAMBDA_NAME=adder -t adder-lambda .
docker build -f docker/lambda.Dockerfile --build-arg LAMBDA_NAME=multiplier -t multiplier-lambda .
```

**Note:** A single unified `lambda.Dockerfile` is used for all lambdas with `LAMBDA_NAME` as a build argument.

### Run individual containers
```bash
# Must specify handler as command argument
docker run -p 9001:8080 adder-lambda adder.main.handler
docker run -p 9002:8080 multiplier-lambda multiplier.main.handler
```

**Note:** The handler must be specified at runtime because Docker ARG variables (like `LAMBDA_NAME`) are only available at build-time, not runtime.

### Run all Lambdas with Docker Compose
```bash
# Start all services
docker-compose up -d

# Services will be available at:
# - Adder Lambda: http://localhost:9001/2015-03-31/functions/function/invocations
# - Multiplier Lambda: http://localhost:9002/2015-03-31/functions/function/invocations

# Check logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Test Lambda locally
```bash
# In another terminal
curl -XPOST "http://localhost:9001/2015-03-31/functions/function/invocations" \
  -d '{"a": 5, "b": 3}'
```

---

## Project Structure

```
.venv/                      # Unified environment (all dependencies for IDE)
lambdas/
  adder/
    pyproject.toml          # Adder package definition
    __init__.py
    main.py
    add.py
    custom/
      add.py
  multiplier/
    pyproject.toml          # Multiplier package definition
    __init__.py
    main.py
tests/
  lambdas/
    adder/
      test_adder.py
    multiplier/
      test_multiplier.py
  e2e/
    test_workflow.py
docker/
  adder.Dockerfile          # Multi-stage build with UV
  multiplier.Dockerfile     # Multi-stage build with UV
pyproject.toml              # Workspace root with dev dependencies
uv.lock                     # Locked dependencies
Makefile                    # Ergonomic commands
```

---

## Environment Management

### Sync dependencies (optional - auto-runs with `uv run`)
```bash
make sync
# or
uv sync --all-extras
```

**Note**: You usually don't need to run this manually. UV automatically syncs when you run `make test`, `make format`, etc.

### Add a dependency to a lambda
```bash
# Edit lambdas/adder/pyproject.toml to add dependency
# Then run any command (auto-syncs):
make test-adder
# Or manually sync:
make sync
```

### Add a dev dependency (pytest, ruff, etc.)
```bash
# Edit root pyproject.toml [project.optional-dependencies.dev]
# Then run any command (auto-syncs):
make test
# Or manually sync:
make sync
```

### Clean all environments
```bash
make clean
# Removes .venv and all caches
```

### Verify dependency isolation
```bash
# Check what gets exported for Docker
uv export --package adder --no-dev --no-hashes --no-editable
uv export --package multiplier --no-dev --no-hashes --no-editable
```

---

## Makefile Commands Reference

**Development (unified .venv):**
- `make format` - Format all code with ruff
- `make lint` - Lint all code with ruff
- `make typecheck` - Type check all code with basedpyright
- `make test` - Run format, lint, typecheck, and all unit tests
- `make test-only` - Run all unit tests only
- `make test-e2e` - Run E2E tests (requires docker-compose up -d)

**Adder Lambda (isolated):**
- `make test-adder` - Run format, lint, typecheck, and adder tests
- `make test-only-adder` - Run adder unit tests only
- `make format-adder` - Format adder code
- `make lint-adder` - Lint adder code
- `make typecheck-adder` - Type check adder code
- `make docker-adder` - Build adder Docker image

**Multiplier Lambda (isolated):**
- `make test-multiplier` - Run format, lint, typecheck, and multiplier tests
- `make test-only-multiplier` - Run multiplier unit tests only
- `make format-multiplier` - Format multiplier code
- `make lint-multiplier` - Lint multiplier code
- `make typecheck-multiplier` - Type check multiplier code
- `make docker-multiplier` - Build multiplier Docker image

**Setup (edge cases only):**
- `make sync` - Manually sync dependencies (usually not needed - auto-runs with `uv run`)
- `make install` - Same as `make sync`
- `make clean` - Remove all virtual environments and caches

---

## Troubleshooting

### Dependencies not updating
```bash
# Re-sync dependencies (usually auto-happens)
make sync

# Or force clean reinstall
make clean
make sync
```

### Import errors in IDE
```bash
# Recreate virtual environment
make clean
make test  # This will auto-sync

# Reload IDE window
# VS Code: Cmd/Ctrl+Shift+P → "Developer: Reload Window"
```

### Docker build fails
```bash
# Verify environment exports minimal requirements
uv export --package adder --no-dev --no-hashes --no-editable

# Rebuild without cache
docker build -f docker/adder.Dockerfile --no-cache -t adder-lambda .
```

### Tests fail with import errors
```bash
# Make sure you're in the right directory
# For isolated tests, UV automatically handles the environment
make test-only-adder

# For unified tests
uv run pytest tests/lambdas/adder -v
```

---

## Why UV Workspaces?

**Benefits:**
- ✅ **Fast**: UV is significantly faster than pip/Hatch
- ✅ **Simple**: One tool for everything (no Hatch + UV combo)
- ✅ **Isolated**: Each lambda is a proper Python package
- ✅ **Unified Development**: Single .venv for IDE with all dependencies
- ✅ **Isolated Production**: Each lambda exports only its dependencies
- ✅ **Ergonomic**: Makefile provides simple commands like `make test-adder`
- ✅ **Deterministic**: uv.lock ensures reproducible builds

**Trade-offs:**
- ⚠️ UV workspaces share a single virtual environment (`.venv`)
  - Not an issue: Docker builds still get isolated dependencies
  - Tests run in the shared environment but verify isolation via exports

See [`docs/MIGRATION_PLAN.md`](docs/MIGRATION_PLAN.md) for the full decision process.
