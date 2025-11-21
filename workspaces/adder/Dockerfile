FROM ghcr.io/astral-sh/uv:0.9.10 AS uv-source

FROM public.ecr.aws/lambda/python:3.12 AS base

# install uv
COPY --from=uv-source /uv /uvx /bin/

# set uv environment variables to compile a faster python code
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0

COPY . ${LAMBDA_TASK_ROOT}/

WORKDIR ${LAMBDA_TASK_ROOT}

FROM base AS production
# Omit any development dependencies (`--no-dev`).
RUN uv export --frozen --no-dev --no-editable -o requirements.txt --package adder && \
    uv pip install -r requirements.txt --system

CMD [ "adder.main.handler" ]
