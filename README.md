# AWS Lambda Functions Collection

A Python project using Hatch for dependency management, featuring multiple AWS Lambda functions with **isolated environments for Docker builds** and a **unified environment for development**.

## Prerequisites

- [Hatch](https://hatch.pypa.io/latest/install/) installed
- [UV](https://docs.astral.sh/uv/getting-started/installation/) installed

## Quick Start

1. Run tests: `hatch run test`
2. Open your preferred IDE

**That's it!** Hatch automatically creates environments when needed.

### How It Works

**For Development (IDE)**
- Uses `.venv` with **all** dependencies
- No import errors, full autocomplete
- Just works

**For Production (Docker)**
- Each lambda has isolated environment
- `hatch run adder:test` uses only adder dependencies
- `hatch run multiplier:test` uses only multiplier dependencies
- Minimal Docker images guaranteed

---

## Running Tests

### Full validation (recommended before commit):
```bash
hatch run test
# Runs: format + lint + typecheck + pytest (all Lambdas)
```

### Quick test iteration:
```bash
hatch run test-only
# Just runs pytest for all Lambdas
```

### Test specific Lambda with isolation:
```bash
hatch run adder:test        # Only adder dependencies
hatch run multiplier:test   # Only multiplier dependencies
```

### End-to-End tests:
```bash
# 1. Start the services
docker-compose up -d
# 2. Run E2E tests (tests actual Docker containers)
hatch run test-e2e
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
Linting, formatting and type checking are performed automatically also during the test commands.

### Type Checking
```bash
hatch run typecheck
```

### Linting
```bash
hatch run lint
```

### Formatting
```bash
hatch run format
```

---

## Docker Build

### Build and Run individual Lambda images
```bash
docker build -f docker/adder.Dockerfile -t adder-lambda .
docker build -f docker/multiplier.Dockerfile -t multiplier-lambda .
```

```bash
docker run -p 9001:8080 adder-lambda
docker run -p 9002:8080 multiplier-lambda
```

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

This starts both Lambda containers and makes them available for E2E testing.

### Test Lambda locally
```bash
# In another terminal
curl -XPOST "http://localhost:9001/2015-03-31/functions/function/invocations" \
  -d '{"a": 5, "b": 3}'
```

---

## Project Structure

```
.venv/                      # IDE uses this (all dependencies)
src/lambdas/
  adder/
    .venv/                  # CLI uses this (only adder deps)
    main.py
  multiplier/
    .venv/                  # CLI uses this (only multiplier deps)
    main.py
tests/
  lambdas/
    adder/
    multiplier/
  e2e/
docker/
  adder.Dockerfile
  multiplier.Dockerfile
pyproject.toml              # Single project, multiple environments
```

---

## Environment Management

### List environments
```bash
hatch env show
```

### Show environment locations
```bash
hatch env find default      # .venv
hatch env find adder        # src/lambdas/adder/.venv
hatch env find multiplier   # src/lambdas/multiplier/.venv
```

### Recreate environments (when dependencies change)
```bash
hatch env prune
hatch env create default
hatch env create adder
hatch env create multiplier
```

---

## Troubleshooting

### Dependencies not updating
```bash
# Remove all environments and let Hatch recreate them
hatch env prune
hatch run test  # Auto-recreates with new dependencies
```

### Import errors in IDE
```bash
# Recreate default environment
hatch env remove default
hatch run test  # Auto-recreates .venv

# Reload IDE window
# VS Code: Cmd/Ctrl+Shift+P → "Developer: Reload Window"
```

### Docker build fails
```bash
# Verify environment exports minimal requirements
hatch dep show requirements --feature adder

# Rebuild without cache
docker build -f docker/adder.Dockerfile --no-cache -t adder-lambda .
```
