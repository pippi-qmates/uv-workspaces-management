# AWS Lambda Functions Collection

A Python Test-Driven Development project using Hatch (with UV) for dependency management, featuring multiple AWS Lambda functions organized as a single project with independent environments.

## Prerequisites

- [Hatch](https://hatch.pypa.io/latest/install/) installed
- [UV](https://docs.astral.sh/uv/getting-started/installation/) installed

## Setup
No setup needed other than installing Hatch and UV systemwide.
Hatch automatically creates needed environments when you run any hatch command.

---

## Running Tests

### Full validation for all Lambdas (recommended before commit):
```bash
hatch run test
# Runs: format + lint + typecheck + pytest (all Lambdas)
```

### Quick test iteration (skip static analysis):
```bash
hatch run test-only
# Just runs pytest for all Lambdas
```

### Full validation for specific Lambda:
```bash
hatch run adder:test
# Runs: format + lint + typecheck + pytest (JUST adder)

hatch run multiplier:test
# Runs: format + lint + typecheck + pytest (JUST multiplier)
```

### Quick test for specific Lambda:
```bash
hatch run adder:test-only
hatch run multiplier:test-only
```

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

### Auto-fix linting issues
```bash
hatch run ruff check src tests --fix
```

### Formatting
```bash
hatch run format
```

---

## Docker Build

Each Lambda can be built and deployed independently:

### Build Lambda image
```bash
# Build adder
docker build -f docker/adder.Dockerfile -t adder-lambda .

# Build multiplier
docker build -f docker/multiplier.Dockerfile -t multiplier-lambda .

# Or use Hatch scripts
hatch run adder:build-docker
hatch run multiplier:build-docker
```

### Test Lambda locally
```bash
# Run the Lambda container
docker run -p 9000:8080 adder-lambda

# In another terminal, invoke it
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"a": 5, "b": 3}'
```

### Build without tests (faster)
```bash
docker build -f docker/adder.Dockerfile \
  --target production \
  -t adder-lambda .
```

### Advanced: Cache usage
Docker build cache mounts significantly speed up rebuilds. The cache persists across builds automatically.

---

# Additional Project info

---

## Ruff Configuration

The project uses Ruff with the following rules enabled:
- **E, W**: pycodestyle errors and warnings
- **F**: Pyflakes (logical errors)
- **I**: isort (import sorting)
- **C**: Complexity and comprehensions
- **B**: flake8-bugbear (likely bugs)
- **N**: pep8-naming (naming conventions)
- **ANN**: flake8-annotations (type hints enforcement)

## Project Structure

This is a single Hatch project containing multiple Lambda functions:

- **src/lambdas/**: Lambda function modules
  - **adder/**: Addition Lambda
  - **multiplier/**: Multiplication Lambda
  - **common/**: Shared utilities (optional)
- **tests/lambdas/**: Test files organized by Lambda
- **docker/**: Dockerfile for each Lambda
- **pyproject.toml**: Single project configuration with Hatch environments

Each Lambda is managed through Hatch environments, allowing:
- Independent dependency management via optional dependencies
- Lambda-specific test runs
- Isolated development environments

## Adding a New Lambda

1. Create Lambda module:
   ```bash
   mkdir -p src/lambdas/new_lambda
   touch src/lambdas/new_lambda/__init__.py
   touch src/lambdas/new_lambda/main.py
   ```

2. Create test directory:
   ```bash
   mkdir -p tests/lambdas/new_lambda
   touch tests/lambdas/new_lambda/test_new_lambda.py
   ```

3. Add to `pyproject.toml`:
   ```toml
   [project.optional-dependencies]
   new-lambda = [
       # Add new-lambda dependencies here
   ]

   [tool.hatch.envs.new-lambda]
   features = ["new-lambda"]
   [tool.hatch.envs.new-lambda.scripts]
   test-only = "pytest tests/lambdas/new_lambda -v"
   test = [
       "ruff format src/lambdas/new_lambda tests/lambdas/new_lambda",
       "ruff check src/lambdas/new_lambda tests/lambdas/new_lambda",
       "basedpyright src/lambdas/new_lambda tests/lambdas/new_lambda",
       "test-only",
   ]
   build-docker = "docker build -f docker/new-lambda.Dockerfile -t new-lambda ."

   # Add to default env features
   [tool.hatch.envs.default]
   features = ["adder", "multiplier", "new-lambda", "dev"]  # Add here
   ```

4. Create Dockerfile:
   ```bash
   # Copy and modify docker/adder.Dockerfile
   cp docker/adder.Dockerfile docker/new-lambda.Dockerfile
   # Update feature name and source paths
   ```

5. **Test your new Lambda:**
   ```bash
   hatch run new-lambda:test
   ```

   Note: The environment will be created automatically on first run.

## Hatch Environments

This project uses Hatch environments (with UV installer for speed) to manage Lambda-specific dependencies.

### Available environments:
- `default`: All Lambdas + dev tools (linting, testing, type checking)
- `adder`: Adder Lambda + dev tools
- `multiplier`: Multiplier Lambda + dev tools

### Environment Management

**List environments and their status:**
```bash
hatch env show
```

**Prune (remove) all environments:**
```bash
hatch env prune
```
Use this when:
- Dependencies have changed in `pyproject.toml`
- Environments are corrupted or behaving unexpectedly
- You want to start fresh

**Prune and recreate specific environment:**
```bash
hatch env prune && hatch run adder:test
# Removes all envs, then creates and runs tests in adder env
```

**Note:** You typically don't need to manually create environments - Hatch creates them automatically on first use.

### Running commands:
```bash
# Run in default environment (all Lambdas)
hatch run test

# Run in specific Lambda environment
hatch run adder:test
hatch run multiplier:test
```

## Troubleshooting

### Dependencies not updating

If you've modified `pyproject.toml` but changes aren't reflected:

```bash
# Remove all environments and let Hatch recreate them
hatch env prune
hatch run test  # Recreates default env with new dependencies
```

### Import errors or module not found

```bash
# Ensure you're in the project root directory
pwd  # Should show .../uv-workspaces-management

# Recreate the environment
hatch env prune
hatch run test-only
```

### Docker build fails

```bash
# Check if pyproject.toml is valid
hatch env show

# Rebuild from scratch without cache
docker build -f docker/adder.Dockerfile --no-cache -t adder-lambda .
```

### Slow environment creation

Environment creation should be fast (thanks to UV). If it's slow:
- Check your internet connection (first-time package downloads)
- Check if UV is installed: `uv --version`
- Consider using `hatch env prune` to clear corrupted cache

