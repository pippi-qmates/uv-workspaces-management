# =============================================================================
# Universal Dockerfile for all Lambda packages
# =============================================================================
# This multi-stage Dockerfile builds any Lambda from the packages/ directory
# using the LAMBDA_NAME build argument.
#
# Stages:
#   1. builder: Exports minimal requirements for the specific package
#   2. production: AWS Lambda runtime with dependencies installed
#
# Usage:
#   docker build -f docker/lambda.Dockerfile --build-arg LAMBDA_NAME=adder -t adder-lambda .
# =============================================================================

ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS builder

ARG LAMBDA_NAME

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /build

# Copy workspace files to export requirements for specific lambda only
COPY pyproject.toml .
COPY uv.lock .
COPY packages/${LAMBDA_NAME}/pyproject.toml packages/${LAMBDA_NAME}/

# Export only lambda's dependencies (no dev dependencies, no local-reference, no editable installs)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv export --package ${LAMBDA_NAME} --no-dev --no-hashes --no-editable | grep -v "^\\./packages/${LAMBDA_NAME}" > requirements.txt

# Production stage
FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

ARG LAMBDA_NAME

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=/build/requirements.txt,target=/requirements.txt \
    pip install -r /requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy only specific lambda source code
COPY packages/${LAMBDA_NAME} ${LAMBDA_TASK_ROOT}/${LAMBDA_NAME}

# CMD is specified in docker-compose.yml per service
# This allows the same Dockerfile to build different lambda handlers
