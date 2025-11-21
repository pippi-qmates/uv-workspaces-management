from multiplier.main import handler, multiply


def test_multiply() -> None:
    assert multiply(2, 3) == 6


def test_handler() -> None:
    event = {"a": 4, "b": 5}
    result = handler(event, None)
    assert result == {"result": 20}
