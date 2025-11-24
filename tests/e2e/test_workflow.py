import httpx


def test_calculator_workflow() -> None:
    # Step 1: Call adder Lambda
    adder_response = httpx.post(
        "http://localhost:9001/2015-03-31/functions/function/invocations",
        json={"a": 5, "b": 3},
        timeout=5.0,
    )

    assert adder_response.status_code == 200
    adder_result = adder_response.json()
    sum_result = adder_result["result"]

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

    assert product == 55  # 11 * 5


def test_adder_lambda_standalone() -> None:
    response = httpx.post(
        "http://localhost:9001/2015-03-31/functions/function/invocations",
        json={"a": 10, "b": 20},
        timeout=5.0,
    )

    assert response.status_code == 200
    result = response.json()
    assert result["result"] == 33  # 10 + 20 + 3


def test_multiplier_lambda_standalone() -> None:
    response = httpx.post(
        "http://localhost:9002/2015-03-31/functions/function/invocations",
        json={"a": 6, "b": 7},
        timeout=5.0,
    )

    assert response.status_code == 200
    result = response.json()
    assert result["result"] == 42  # 6 * 7
