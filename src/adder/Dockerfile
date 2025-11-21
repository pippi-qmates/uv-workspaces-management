FROM public.ecr.aws/lambda/python:3.12

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy requirements
COPY pyproject.toml uv.lock ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN uv export --frozen --format requirements-txt > requirements.txt && uv pip install -r requirements.txt --target ${LAMBDA_TASK_ROOT}

# Copy function code
COPY . ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "adder.handler" ]
