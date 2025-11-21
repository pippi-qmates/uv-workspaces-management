# docker/multiplier.Dockerfile
ARG PYTHON_VERSION=3.12
ARG HATCH_VERSION=1.13.0

FROM python:${PYTHON_VERSION}-slim AS base

# Re-declare ARG after FROM to make it available in this stage
ARG HATCH_VERSION=1.13.0

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

# Copy pyproject.toml to export requirements
COPY pyproject.toml .
RUN hatch dep show requirements --feature multiplier > requirements.txt

FROM public.ecr.aws/lambda/python:${PYTHON_VERSION} AS production

# Re-declare ARG after FROM
ARG PYTHON_VERSION=3.12

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,from=builder,source=/build/requirements.txt,target=/requirements.txt \
    pip install -r /requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY src/lambdas/__init__.py ${LAMBDA_TASK_ROOT}/lambdas/
COPY src/lambdas/multiplier ${LAMBDA_TASK_ROOT}/lambdas/multiplier

CMD [ "lambdas.multiplier.main.handler" ]
