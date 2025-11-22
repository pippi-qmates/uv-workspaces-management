# docker/lambda.Dockerfile
# Universal Dockerfile for all Lambda functions
ARG PYTHON_VERSION=3.12
ARG LAMBDA_NAME

FROM python:${PYTHON_VERSION}-slim AS base

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /build

# Test stage - runs tests during build (optional, for CI/CD)
FROM base AS test

ARG LAMBDA_NAME

# This stage is not used by default - tests run via make test-*
# It's here for CI/CD pipelines that want to run tests in Docker
RUN echo "Test stage placeholder - use make test-${LAMBDA_NAME} instead"

# Builder stage - export requirements
FROM base AS builder

ARG LAMBDA_NAME

# Copy workspace files to export requirements for specific lambda only
COPY pyproject.toml .
COPY uv.lock .
COPY packages/${LAMBDA_NAME}/pyproject.toml packages/${LAMBDA_NAME}/

# Export only lambda's dependencies (no dev dependencies, no editable installs)
# Filter out the local package reference
RUN --mount=type=cache,target=/root/.cache/uv \
    uv export --package ${LAMBDA_NAME} --no-dev --no-hashes --no-editable | grep -v "^\\./packages/${LAMBDA_NAME}" > requirements.txt

# Production stage
FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

ARG PYTHON_VERSION=3.12
ARG LAMBDA_NAME

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=/build/requirements.txt,target=/requirements.txt \
    pip install -r /requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy only specific lambda source code
COPY packages/${LAMBDA_NAME} ${LAMBDA_TASK_ROOT}/${LAMBDA_NAME}

# CMD is specified in docker-compose.yml per service
# This allows the same Dockerfile to build different lambda handlers
