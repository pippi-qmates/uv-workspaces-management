"""
End-to-end tests for Lambda workflows.

These tests simulate Step Functions orchestration by calling Lambda containers
in sequence and asserting the final workflow results.

Prerequisites:
    Start the Lambda containers with: docker-compose up -d

Note:
    The containers remain running between test runs for faster iteration.
    To stop: docker-compose down
"""

import httpx


def test_calculator_workflow() -> None:
    """
    Test the calculator workflow: adder -> multiplier.

    Workflow:
        1. Input: {"a": 5, "b": 3}
        2. Adder: sum = a + b + 3 = 11
        3. Multiplier: product = sum * a = 55
        4. Assert final result
    """
    # Step 1: Call adder Lambda
    adder_response = httpx.post(
        "http://localhost:9001/2015-03-31/functions/function/invocations",
        json={"a": 5, "b": 3},
        timeout=5.0,
    )

    assert adder_response.status_code == 200
    adder_result = adder_response.json()
    sum_result = adder_result["result"]

    # Verify adder result
    assert sum_result == 11  # 5 + 3 + 3

    # Step 2: Call multiplier Lambda with sum and original 'a'
    multiplier_response = httpx.post(
        "http://localhost:9002/2015-03-31/functions/function/invocations",
        json={"a": sum_result, "b": 5},
        timeout=5.0,
    )

    assert multiplier_response.status_code == 200
    multiplier_result = multiplier_response.json()
    product = multiplier_result["result"]

    # Assert final workflow result
    assert product == 55  # 11 * 5


def test_adder_lambda_standalone() -> None:
    """Test adder Lambda in isolation."""
    response = httpx.post(
        "http://localhost:9001/2015-03-31/functions/function/invocations",
        json={"a": 10, "b": 20},
        timeout=5.0,
    )

    assert response.status_code == 200
    result = response.json()
    assert result["result"] == 33  # 10 + 20 + 3


def test_multiplier_lambda_standalone() -> None:
    """Test multiplier Lambda in isolation."""
    response = httpx.post(
        "http://localhost:9002/2015-03-31/functions/function/invocations",
        json={"a": 6, "b": 7},
        timeout=5.0,
    )

    assert response.status_code == 200
    result = response.json()
    assert result["result"] == 42  # 6 * 7
