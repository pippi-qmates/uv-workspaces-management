# docker/adder.Dockerfile
ARG PYTHON_VERSION=3.12
ARG HATCH_VERSION=1.13.0

FROM python:${PYTHON_VERSION}-slim AS base

# Re-declare ARG after FROM to make it available in this stage
ARG HATCH_VERSION=1.13.0

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

# Copy pyproject.toml to export requirements
COPY pyproject.toml .
RUN hatch dep show requirements --feature adder > requirements.txt

# Production stage
FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

# Re-declare ARG after FROM
ARG PYTHON_VERSION=3.12

# Install dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=/build/requirements.txt,target=/requirements.txt \
    pip install -r /requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy only adder source code
COPY src/lambdas/__init__.py ${LAMBDA_TASK_ROOT}/lambdas/
COPY src/lambdas/adder ${LAMBDA_TASK_ROOT}/lambdas/adder

CMD [ "lambdas.adder.main.handler" ]
