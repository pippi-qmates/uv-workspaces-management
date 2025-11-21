# Running Lambdas Locally

This document explains how to run and test Lambda functions locally using Docker containers.

## Table of Contents

- [Quick Start](#quick-start)
- [Design Decisions](#design-decisions)
- [Why Not LocalStack?](#why-not-localstack)
- [Alternatives Considered](#alternatives-considered)

---

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Hatch environment ready (run any `hatch run` command to auto-create)

### Start Lambda Containers

```bash
# Build and start both Lambda containers
docker-compose up -d
```

The containers will remain running between test runs for faster iteration. This saves minutes throughout the day.

### Run E2E Tests

```bash
# Run end-to-end workflow tests
hatch run test-e2e
```

E2E tests simulate Step Functions orchestration by calling Lambda containers in sequence and asserting workflow results. See `tests/e2e/test_workflow.py` for examples.

### Stop Containers

```bash
# When done for the day
docker-compose down
```

---

## Design Decisions

### 1. Docker Compose Handles Image Building

**Decision**: Use `docker-compose up` to build images automatically, no separate build step needed.

**Rationale**:
- Simpler workflow: One command does everything
- Docker Compose caches builds efficiently
- No need for separate `build-docker` Hatch commands
- Standard Docker workflow developers already know

### 2. Containers Stay Running Between Tests

**Decision**: Developer manually starts/stops containers with `docker-compose up/down`.

**Rationale**:
- **Speed**: Saves minutes per day by not rebuilding between test runs
- **Standard practice**: `docker-compose up -d` is a de-facto standard
- **Flexibility**: Developer controls when containers run
- **No magic**: Explicit is better than implicit

### 3. E2E Tests Separate from Unit Tests

**Decision**: `hatch run test` runs only unit tests, `hatch run test-e2e` runs E2E tests.

**Rationale**:
- **Fast feedback**: Unit tests complete in milliseconds
- **No Docker dependency**: CI/CD can run unit tests without Docker
- **Developer choice**: Run E2E only when testing integrations
- **Clear separation**: Different purposes, different commands

### 4. Python E2E Tests Over Other Tools

**Decision**: Use pytest with `requests` library to orchestrate Lambda calls.

**Rationale**:
- **Minimal dependencies**: Only adds `requests` to dev dependencies
- **Familiar tools**: Already using pytest for unit tests
- **Full control**: Explicitly code workflow logic (educational)
- **Flexible**: Easy to add assertions, retries, complex workflows
- **Fast**: Direct HTTP calls, no overhead
- **Test Lambda logic, not infrastructure**: Terraform tests infrastructure, E2E tests test Lambda workflows

### 5. No LocalStack or AWS Simulation

**Decision**: Test Lambdas directly via HTTP, don't simulate AWS services locally.

**Rationale**:
- **Separation of concerns**: Lambda logic vs infrastructure configuration
- **Terraform is source of truth**: Infrastructure defined in Terraform, not duplicated in LocalStack
- **Avoid configuration drift**: No need to keep LocalStack configs in sync with Terraform
- **Simpler is better**: Direct HTTP testing is easier to understand and maintain
- **No paid tools needed**: LocalStack Pro required for container images

---

## Why Not LocalStack?

We initially explored LocalStack for simulating AWS Step Functions locally, but decided against it:

### LocalStack Limitations

1. **Container Images Require Pro**: Lambda container images are a paid feature in LocalStack
2. **Configuration duplication**: Our cloud infrastructure is managed by Terraform, not LocalStack configs
3. **Cannot reuse production configs**: LocalStack requires separate configuration that duplicates our Terraform code
4. **Maintenance burden**: Keeping LocalStack configs in sync with Terraform is error-prone and time-consuming

### What LocalStack Would Have Provided

- Visual Step Functions workflow simulation
- AWS-like API for Lambda/Step Functions
- CloudWatch Logs simulation
- IAM role testing

### Why We Don't Need It

- **Our workflow is simple**: Just chain HTTP calls between Lambdas
- **E2E tests are explicit**: Clearly shows what Step Functions would do
- **Educational value**: Understanding the workflow beats simulating it
- **No AWS lock-in**: Pure HTTP testing works anywhere
- **Terraform is our source of truth**: Infrastructure is defined in Terraform, not LocalStack
- **No config duplication**: We test Lambda logic, Terraform tests infrastructure

### When You Might Need LocalStack Pro

Consider LocalStack Pro if you:
- Need to test complex Step Functions with parallel execution, retries, error handling
- Want to test API Gateway, DynamoDB, S3 integrations
- Need to simulate AWS environments for entire teams
- Have budget for paid tools

---

## Alternatives Considered

### 1. AWS SAM CLI

**Pros**:
- Official AWS tool
- Free
- Supports container images
- Can simulate API Gateway

**Cons**:
- Additional tool to install (heavy)
- YAML configuration overhead
- Overkill for our simple use case

**Verdict**: Too heavy for our needs

### 2. Shell Script Orchestration

**Pros**:
- Very simple
- No test framework needed

**Cons**:
- Harder to assert complex results
- Less maintainable than pytest
- No test runner integration

**Verdict**: Python tests are more maintainable

### 3. API Gateway Alternatives (for API Lambdas)

If you were building API Lambdas (REST endpoints), you could use:

- **nginx**: Reverse proxy to route HTTP requests to Lambda containers
- **Caddy**: Modern reverse proxy with automatic HTTPS
- **Traefik**: Dynamic routing based on labels

**Example nginx config**:
```nginx
location /api/add {
    proxy_pass http://localhost:9001/2015-03-31/functions/function/invocations;
}

location /api/multiply {
    proxy_pass http://localhost:9002/2015-03-31/functions/function/invocations;
}
```

**When to use**: If you need to simulate API Gateway routing/auth locally.

---

## Summary

**Our approach**:
- ✅ Simple: Docker Compose + pytest
- ✅ Fast: Containers stay running
- ✅ Familiar: Standard tools developers know
- ✅ Educational: Explicit workflow orchestration
- ✅ Free: No paid services required

**Trade-offs**:
- ❌ No visual Step Functions workflow
- ❌ No AWS-specific features (retries, error handling simulation)

For simple Lambda workflows, direct HTTP testing is the most pragmatic choice.
