# Migration Plan: UV Workspaces to Single Hatch Project

## Revised Approach: Single Project with Hatch Environments

**Key Insight:** Instead of treating adder and multiplier as separate workspace projects, treat them as **different Lambda functions within a single project**, managed through Hatch environments and build configurations.

## Current State

**UV Workspace Structure:**
```
workspaces/
  adder/          # Separate project with own pyproject.toml
  multiplier/     # Separate project with own pyproject.toml
pyproject.toml    # Root workspace config
uv.lock           # Unified lock file
```

## Target State

**Single Hatch Project:**
```
src/
  lambdas/
    adder/        # Lambda function module
    multiplier/   # Lambda function module
    common/       # Shared utilities (optional)
tests/
  lambdas/
    adder/
    multiplier/
docker/
  adder.Dockerfile
  multiplier.Dockerfile
pyproject.toml    # Single project config with Hatch environments
```

## Why This Approach is Better

### Advantages

1. **Unified Dependency Management:**
   - All shared dependencies defined once
   - Lambda-specific dependencies in optional dependency groups
   - Single lock file (via pip-compile or similar)
   - Easier to keep dependencies in sync

2. **Hatch Environment Matrix:**
   - Use environments to isolate Lambda-specific dependencies
   - Example: `hatch env create adder` vs `hatch env create multiplier`
   - Can run tests per-Lambda: `hatch run adder:test`

3. **Simplified Docker Builds:**
   - Single source tree to copy
   - Build different Lambda images using Hatch build hooks or environment variables
   - Can use `hatch build` with custom targets per Lambda

4. **Common Code Sharing:**
   - Easy to create shared utilities in `src/lambdas/common/`
   - No workspace dependency magic needed
   - Direct imports: `from lambdas.common import utils`

5. **Single Configuration:**
   - One pyproject.toml to maintain
   - Unified linting/formatting/type checking config
   - Consistent versioning across all Lambdas

### Comparison Table

| Aspect | UV Workspaces | Single Hatch Project |
|--------|---------------|---------------------|
| **Shared Dependencies** | Must duplicate or use workspace deps | Defined once in [project.dependencies] |
| **Lambda-specific Deps** | Per-project pyproject.toml | Optional dependency groups |
| **Common Code** | Workspace dependencies | Direct module imports |
| **Testing** | `uv run --directory workspaces/adder pytest` | `hatch run adder:test` |
| **Docker Build** | Copy workspace structure | Copy single src tree, build specific target |
| **Config Files** | 3 pyproject.toml files | 1 pyproject.toml file |
| **Version Management** | Manual sync across projects | Single version for all |

## Migration Strategy

### Phase 1: Restructure Source Code

**Action Items:**

1. **Create new source structure:**
   ```
   src/lambdas/
     adder/
       __init__.py
       main.py
       add.py
       custom/
         add.py
     multiplier/
       __init__.py
       main.py
   ```

2. **Move tests:**
   ```
   tests/lambdas/
     adder/
       test_adder.py
     multiplier/
       test_multiplier.py
   ```

3. **Update imports:**
   - Change from `from adder.custom.add import custom_add`
   - To: `from lambdas.adder.custom.add import custom_add`

### Phase 2: Create Single pyproject.toml

**Example configuration:**

```toml
[project]
name = "aws-lambdas"
version = "0.1.0"
description = "AWS Lambda Functions Collection"
requires-python = ">=3.12"
dependencies = []  # No shared runtime dependencies

[project.optional-dependencies]
# Each Lambda declares ALL its dependencies explicitly
adder = [
    "aws-lambda-powertools>=3.23.0",
    # Add any other adder-specific dependencies
]
multiplier = [
    # Add multiplier-specific dependencies if any
    # Even if it needs same lib as adder, declare it here explicitly
]
# Dev dependencies for local development only
dev = [
    "basedpyright>=1.34.0",
    "pytest>=8.0.0",
    "ruff>=0.8.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/lambdas"]

# Environment for adder Lambda
[tool.hatch.envs.adder]
features = ["adder"]
[tool.hatch.envs.adder.scripts]
test = "pytest tests/lambdas/adder -v"
build-docker = "docker build -f docker/adder.Dockerfile -t adder-lambda ."

# Environment for multiplier Lambda
[tool.hatch.envs.multiplier]
features = ["multiplier"]
[tool.hatch.envs.multiplier.scripts]
test = "pytest tests/lambdas/multiplier -v"
build-docker = "docker build -f docker/multiplier.Dockerfile -t multiplier-lambda ."

# Default dev environment with all dependencies
[tool.hatch.envs.default]
features = ["adder", "multiplier", "dev"]
[tool.hatch.envs.default.scripts]
# Individual commands
format = "ruff format src tests"
lint = "ruff check src tests"
typecheck = "basedpyright src tests"
# Note: 'test' is defined in Makefile as composite command
# For direct hatch usage: hatch run pytest

[tool.pytest.ini_options]
pythonpath = ["src"]
testpaths = ["tests"]

[tool.ruff]
line-length = 120
target-version = "py312"
src = ["src"]

[tool.ruff.lint]
select = ["E", "W", "F", "I", "C", "B", "N", "ANN"]
ignore = []
```

### Phase 3: Docker Build Strategy

**Selected Strategy: Requirements.txt Export with Build Optimizations**

This approach uses Hatch for dependency management while adopting advanced Docker techniques for optimal builds.

**Key Techniques from Best Practices:**

| Technique | Benefit |
|-----------|---------|
| **Build Cache Mounts** | Faster rebuilds by caching dependencies |
| **Multi-stage with Test** | Run tests during build, fail fast |
| **Bind Mounts** | Don't copy files into layers unnecessarily |
| **Parameterized Versions** | Easy to update tool versions |
| **Minimal Layer Copying** | Only production code in final image |

**Optimized Dockerfile Template:**

```dockerfile
# docker/adder.Dockerfile
ARG HATCH_VERSION=1.13.0
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS base

# Install hatch once in base layer
RUN pip install hatch==${HATCH_VERSION}

WORKDIR /build

# Test stage - runs tests during build
FROM base AS test

# Mount source files (don't copy into layer)
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=src,target=src \
    --mount=type=bind,source=tests,target=tests \
    --mount=type=cache,target=/root/.cache/pip \
    hatch env create adder && \
    hatch run adder:test

# Builder stage - export requirements
FROM base AS builder

# Use bind mounts to avoid copying files into the layer
RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    hatch dep show requirements --feature adder > requirements.txt

# Production stage
FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=requirements.txt,target=requirements.txt \
    pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy only adder source code
COPY src/lambdas/__init__.py ${LAMBDA_TASK_ROOT}/lambdas/
COPY src/lambdas/adder ${LAMBDA_TASK_ROOT}/lambdas/adder

# If adder uses common utilities:
# COPY src/lambdas/common ${LAMBDA_TASK_ROOT}/lambdas/common

CMD [ "lambdas.adder.main.handler" ]
```

**For multiplier:**

```dockerfile
# docker/multiplier.Dockerfile
ARG HATCH_VERSION=1.13.0
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS base

RUN pip install hatch==${HATCH_VERSION}

WORKDIR /build

FROM base AS test

RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=src,target=src \
    --mount=type=bind,source=tests,target=tests \
    --mount=type=cache,target=/root/.cache/pip \
    hatch env create multiplier && \
    hatch run multiplier:test

FROM base AS builder

RUN --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    hatch dep show requirements --feature multiplier > requirements.txt

FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=requirements.txt,target=requirements.txt \
    pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY src/lambdas/__init__.py ${LAMBDA_TASK_ROOT}/lambdas/
COPY src/lambdas/multiplier ${LAMBDA_TASK_ROOT}/lambdas/multiplier

CMD [ "lambdas.multiplier.main.handler" ]
```

**Advanced Features Explained:**

1. **Build Arguments for Version Control:**
   ```dockerfile
   ARG HATCH_VERSION=1.13.0
   ARG PYTHON_VERSION=3.12
   ```
   - Easy to update tool versions
   - Consistent across stages
   - Can override at build time: `docker build --build-arg HATCH_VERSION=1.14.0`

2. **Build Cache Mounts:**
   ```dockerfile
   RUN --mount=type=cache,target=/root/.cache/pip \
   ```
   - Persists pip cache between builds
   - Dramatically faster rebuilds
   - Shares cache across all Docker builds

3. **Bind Mounts:**
   ```dockerfile
   --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
   ```
   - Files available during RUN but not added to layer
   - Smaller intermediate layers
   - Better layer caching

4. **Test Stage:**
   ```dockerfile
   FROM base AS test
   RUN ... hatch run adder:test
   ```
   - Tests run during build
   - Build fails if tests fail
   - Prevents deploying broken code
   - Can skip in production: `docker build --target production`

5. **Cross-stage Mounts:**
   ```dockerfile
   --mount=type=bind,from=builder,source=requirements.txt,target=requirements.txt \
   ```
   - Use files from other stages without COPY
   - Cleaner layer structure

**Build Commands:**

```bash
# Build with tests (default)
docker build -f docker/adder.Dockerfile -t adder-lambda:latest .

# Build without tests (faster for development iteration)
docker build -f docker/adder.Dockerfile --target production -t adder-lambda:latest .

# Build with custom versions
docker build -f docker/adder.Dockerfile \
  --build-arg PYTHON_VERSION=3.13 \
  --build-arg HATCH_VERSION=1.14.0 \
  -t adder-lambda:latest .

# Build and see cache usage
docker build -f docker/adder.Dockerfile --progress=plain -t adder-lambda:latest .
```

**Why This Is Better:**

✅ **Faster Builds**: Cache mounts speed up rebuilds significantly
✅ **Automated Testing**: Tests run during build, catch issues early
✅ **Smaller Images**: Bind mounts don't bloat intermediate layers
✅ **Flexible**: Can skip test stage when needed
✅ **Maintainable**: Version args make updates easy
✅ **Production-Ready**: Matches industry best practices

### Phase 4: Update Development Workflow

**New Makefile:**

```makefile
.PHONY: format lint typecheck test-only test test-adder test-multiplier
.PHONY: build-adder build-multiplier build-all

# Individual static analysis commands (for targeted fixes)
format:
	hatch run ruff format src tests

lint:
	hatch run ruff check src tests

typecheck:
	hatch run basedpyright src tests

# Quick test run - EXPLICITLY bypassing static analysis
test-only:
	hatch run pytest

# Lambda-specific tests (also bypass static analysis for speed)
test-adder:
	hatch run adder:test

test-multiplier:
	hatch run multiplier:test

# Full validation - runs everything (recommended before commit)
test: format lint typecheck test-only

# Docker builds
build-adder:
	docker build -f docker/adder.Dockerfile -t adder-lambda .

build-multiplier:
	docker build -f docker/multiplier.Dockerfile -t multiplier-lambda .

build-all: build-adder build-multiplier
```

**Usage examples:**

```bash
# Full validation (format + lint + typecheck + tests) - DEFAULT
make test

# Quick test iteration (skip static analysis)
make test-only

# Test specific Lambda
make test-adder

# Fix formatting
make format

# Check linting
make lint

# Type checking
make typecheck

# Build Docker images
make build-adder
make build-all
```

## File Changes Checklist

- [ ] Create new directory structure: `src/lambdas/`, `tests/lambdas/`
- [ ] Move `workspaces/adder/src/adder/` → `src/lambdas/adder/`
- [ ] Move `workspaces/multiplier/src/multiplier/` → `src/lambdas/multiplier/`
- [ ] Move `workspaces/adder/tests/` → `tests/lambdas/adder/`
- [ ] Move `workspaces/multiplier/tests/` → `tests/lambdas/multiplier/`
- [ ] Update all imports in source files
- [ ] Update all imports in test files
- [ ] Create new root `pyproject.toml` with Hatch config
- [ ] Create `docker/` directory
- [ ] Create `docker/adder.Dockerfile`
- [ ] Create `docker/multiplier.Dockerfile`
- [ ] Update `Makefile` with Hatch commands
- [ ] Update `README.md` with new structure and Hatch commands (see Phase 5)
- [ ] Remove `workspaces/` directory
- [ ] Remove old workspace `pyproject.toml` files
- [ ] Remove `uv.lock`

## Phase 5: Update Documentation

### Update README.md

Replace UV-specific content with Hatch instructions:

**Changes Required:**

1. **Update Prerequisites section:**
   ```markdown
   ## Prerequisites
   - [Hatch](https://hatch.pypa.io/latest/install/) installed
   ```

2. **Remove UV installation instructions**

3. **Update Setup section:**
   ```markdown
   ## Setup

   1. **Install Hatch** (if not already installed):

      **macOS/Linux:**
      ```bash
      curl -sSL https://install.python-poetry.org | python3 -
      # Or with pipx
      pipx install hatch
      ```

      **Windows:**
      ```powershell
      pipx install hatch
      ```

   2. **Create development environment**:
      ```bash
      hatch env create
      ```
   ```

4. **Update Running Tests section:**
   ```markdown
   ## Running Tests

   ### Full validation (recommended before commit):
   ```bash
   make test
   # Runs: format + lint + typecheck + pytest
   ```

   ### Quick test iteration (skip static analysis):
   ```bash
   make test-only
   # or
   hatch run pytest
   ```

   ### Run tests for a specific Lambda:
   ```bash
   make test-adder
   make test-multiplier
   # or
   hatch run adder:test
   hatch run multiplier:test
   ```
   ```

5. **Update Code Quality section:**
   ```markdown
   ## Code Quality

   ### Full Validation (before commit)
   ```bash
   make test
   # Runs format + lint + typecheck + tests
   ```

   ### Individual Commands

   **Linting**
   ```bash
   make lint
   # or
   hatch run lint
   ```

   **Type Checking**
   ```bash
   make typecheck
   # or
   hatch run typecheck
   ```

   **Auto-fix linting issues**
   ```bash
   hatch run ruff check src tests --fix
   ```

   **Formatting**
   ```bash
   make format
   # or
   hatch run format
   ```

   **Quick test-only (skip static analysis)**
   ```bash
   make test-only
   ```
   ```

6. **Update Workspace Structure section:**
   ```markdown
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
   ```

7. **Update Adding a New Lambda section:**
   ```markdown
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
      test = "pytest tests/lambdas/new_lambda -v"
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

   5. Update environments:
      ```bash
      hatch env create
      ```
   ```

8. **Update Docker Deployment section:**
   ```markdown
   ## Docker Deployment

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
   ```
   ```

9. **Add new Hatch Environments section:**
   ```markdown
   ## Hatch Environments

   This project uses Hatch environments to manage Lambda-specific dependencies:

   ### Available environments:
   - `default`: All Lambdas + dev tools (linting, testing, type checking)
   - `adder`: Only adder Lambda dependencies
   - `multiplier`: Only multiplier Lambda dependencies

   ### Common commands:
   ```bash
   # List all environments
   hatch env show

   # Remove and recreate all environments
   hatch env prune

   # Run command in specific environment
   hatch run adder:test

   # Run in default environment
   hatch run pytest
   ```
   ```

## Advanced Hatch Features to Leverage

### 1. Environment Matrix (Future Enhancement)

Test multiple Lambda configurations:

```toml
[tool.hatch.envs.test]
features = ["dev"]

[[tool.hatch.envs.test.matrix]]
lambda = ["adder", "multiplier"]
python = ["3.12", "3.13"]
```

Run with: `hatch run test:test`

### 2. Build Hooks

Custom build logic per Lambda:

```toml
[tool.hatch.build.hooks.custom]
path = "build_hooks.py"
```

### 3. Scripts with Arguments

```toml
[tool.hatch.envs.adder.scripts]
invoke = "python -c 'from lambdas.adder.main import handler; print(handler({args}, None))'"
```

Run with: `hatch run adder:invoke '{"a": 5, "b": 3}'`

## Benefits of Single Project Approach

### 1. Shared Dependencies

**Before (UV workspaces):**
```toml
# workspaces/adder/pyproject.toml
dependencies = ["aws-lambda-powertools>=3.23.0"]

# workspaces/multiplier/pyproject.toml
dependencies = []  # If both need same lib, must duplicate
```

**After (Hatch single project):**
```toml
# Single pyproject.toml
dependencies = [
    "aws-lambda-powertools>=3.23.0",  # Shared by all
]
optional-dependencies.adder = [
    "boto3>=1.26.0",  # Only adder needs this
]
```

### 2. Common Code

**Before:** Need workspace dependencies
**After:** Direct imports

```python
# src/lambdas/common/utils.py
def validate_input(data):
    ...

# src/lambdas/adder/main.py
from lambdas.common.utils import validate_input
```

### 3. Versioning

**Before:** Separate versions for each workspace
**After:** Single version, tagged releases include all Lambdas

### 4. Testing

**Before:**
```bash
cd workspaces/adder && pytest
cd workspaces/multiplier && pytest
```

**After:**
```bash
hatch run test              # All tests
hatch run adder:test        # Just adder
hatch run multiplier:test   # Just multiplier
```

## Risks & Considerations

### Potential Issues

1. **Versioning Strategy** ✅ **NOT A CONCERN**
   - **Context**: In the single project, `pyproject.toml` has one version (e.g., `0.1.0`)
   - **Solution**: Lambda deployment versions are independent from project version
   - **Recommended Approach**:
     ```yaml
     # .github/workflows/deploy-lambda.yml
     name: Deploy Lambda
     on:
       push:
         paths:
           - 'src/lambdas/adder/**'
           - 'docker/adder.Dockerfile'

     jobs:
       deploy-adder:
         runs-on: ubuntu-latest
         steps:
           - name: Build and tag with build number
             run: |
               docker build -f docker/adder.Dockerfile \
                 -t adder-lambda:${{ github.run_number }} \
                 -t adder-lambda:latest .

           - name: Deploy to AWS
             run: |
               # Push with build number as version
               docker push adder-lambda:${{ github.run_number }}
     ```
   - **Benefits**:
     - Each Lambda can be deployed independently
     - Build number (`github.run_number`) provides unique versioning
     - Only changed Lambdas trigger deployment (path filters)
     - No need to sync version numbers across Lambdas
   - **Feasible**: Yes, this is a common and recommended pattern for monorepos

2. **Docker images include only what's needed** ✅ **BEST PRACTICE**
   - **Strategy**: Copy only the specific Lambda's code + shared common modules
   - **Example Dockerfile structure**:
     ```dockerfile
     # Copy base package structure
     COPY src/lambdas/__init__.py ${LAMBDA_TASK_ROOT}/lambdas/

     # Copy specific Lambda code
     COPY src/lambdas/adder ${LAMBDA_TASK_ROOT}/lambdas/adder

     # Copy ONLY common modules this Lambda uses (if any)
     COPY src/lambdas/common ${LAMBDA_TASK_ROOT}/lambdas/common

     # DO NOT copy other Lambdas (no multiplier code in adder image)
     ```
   - **Benefits**:
     - Minimal image size
     - Only deploy code that Lambda actually uses
     - If `adder` doesn't use common utilities, don't copy them
     - If `multiplier` doesn't use common utilities, don't copy them
   - **Decision per Lambda**: Only copy `common/` if that Lambda imports from it

3. **Dependency management strategy** ✅ **CLEANER APPROACH**
   - **Strategy**: No shared dependencies in main project, only dev dependencies
   - **Configuration**:
     ```toml
     [project]
     name = "aws-lambdas"
     version = "0.1.0"
     requires-python = ">=3.12"
     dependencies = []  # Empty - no shared runtime dependencies

     [project.optional-dependencies]
     # Each Lambda declares ALL its dependencies explicitly
     adder = [
         "aws-lambda-powertools>=3.23.0",
         "boto3>=1.26.0",
         # ... all adder needs
     ]
     multiplier = [
         "requests>=2.31.0",
         # ... all multiplier needs
     ]
     # Dev dependencies for local development
     dev = [
         "basedpyright>=1.34.0",
         "pytest>=8.0.0",
         "ruff>=0.8.0",
     ]
     ```
   - **Benefits**:
     - No dependency conflicts possible
     - Each Lambda is completely independent
     - Clear what each Lambda requires
     - If two Lambdas need same lib, just declare it twice (explicit > implicit)
     - Easier to understand Lambda-specific requirements
   - **Trade-off**: Some duplication in pyproject.toml, but gains clarity and isolation
   - **Example**: If both `adder` and `multiplier` need `aws-lambda-powertools`, declare it in both optional dependency groups

### Migration Risks

1. **Import changes across codebase**
   - **Risk**: Breaking imports when moving from `adder.main` to `lambdas.adder.main`
   - **Mitigation**:
     - Careful find/replace
     - Comprehensive testing before deployment
     - Update all test files
     - Update Dockerfile CMD paths

2. **Docker build changes**
   - **Risk**: New Dockerfiles might not work as expected
   - **Mitigation**:
     - Test builds locally before committing
     - Test Lambda invocations locally with `docker run`
     - Validate with sample events
   - **Note**: No need to keep old Dockerfiles - Git history preserves them for rollback if needed

### CI/CD Versioning Strategy (Recommended)

**GitHub Actions Setup:**

```yaml
# .github/workflows/deploy-adder.yml
name: Deploy Adder Lambda

on:
  push:
    branches: [main]
    paths:
      - 'src/lambdas/adder/**'
      - 'tests/lambdas/adder/**'
      - 'docker/adder.Dockerfile'
      - 'pyproject.toml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set version
        id: version
        run: |
          # Use build number or commit SHA
          echo "version=${{ github.run_number }}" >> $GITHUB_OUTPUT
          # Alternative: echo "version=${GITHUB_SHA::8}" >> $GITHUB_OUTPUT

      - name: Build Docker image
        run: |
          docker build -f docker/adder.Dockerfile \
            -t adder-lambda:${{ steps.version.outputs.version }} \
            -t adder-lambda:latest .

      - name: Test Lambda locally
        run: |
          docker run -d -p 9000:8080 adder-lambda:${{ steps.version.outputs.version }}
          sleep 2
          curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
            -d '{"a": 5, "b": 3}'

      - name: Push to ECR
        run: |
          aws ecr get-login-password --region us-east-1 | \
            docker login --username AWS --password-stdin $ECR_REGISTRY
          docker tag adder-lambda:${{ steps.version.outputs.version }} \
            $ECR_REGISTRY/adder-lambda:${{ steps.version.outputs.version }}
          docker push $ECR_REGISTRY/adder-lambda:${{ steps.version.outputs.version }}

      - name: Update Lambda function
        run: |
          aws lambda update-function-code \
            --function-name adder-lambda \
            --image-uri $ECR_REGISTRY/adder-lambda:${{ steps.version.outputs.version }}
```

**Separate workflow for multiplier:**

```yaml
# .github/workflows/deploy-multiplier.yml
# Similar structure, different paths and Lambda name
on:
  push:
    branches: [main]
    paths:
      - 'src/lambdas/multiplier/**'
      - 'tests/lambdas/multiplier/**'
      - 'docker/multiplier.Dockerfile'
      - 'pyproject.toml'
```

**Why This Works:**

✅ **Independent Deployments**: Only changed Lambdas get deployed
✅ **Unique Versions**: Each deployment gets unique version (build number or commit SHA)
✅ **Traceability**: Can track which build deployed which Lambda
✅ **Rollback**: Can rollback to specific build number
✅ **No Version Conflicts**: Project version in pyproject.toml is irrelevant for deployment

## Estimated Effort

- **Phase 1 (Restructure):** 1-2 hours
- **Phase 2 (Config):** 1 hour
- **Phase 3 (Docker):** 2-3 hours
- **Phase 4 (Workflow):** 1 hour
- **Testing & Validation:** 2-3 hours

**Total:** 7-10 hours

## Recommendation

**Proceed with single Hatch project approach** because:

✅ Simpler dependency management
✅ Easier to share code between Lambdas
✅ Single configuration to maintain
✅ Better use of Hatch's environment features
✅ Cleaner project structure
✅ Better for your use case than multiple independent projects

This addresses your original concern: **You don't need workspaces at all** - instead, use Hatch environments to manage different Lambda builds from a single unified project.

## Next Steps

Please confirm:
1. **Do you approve this single-project approach?**
2. **Any specific Lambda-specific dependencies I should know about?**
3. **Do you want to keep the Docker builds in separate files or use a single Dockerfile with build args?**
4. **Should I proceed with the migration?**
