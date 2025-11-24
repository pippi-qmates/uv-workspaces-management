from adder.add import add
from adder.custom.add import custom_add
from adder.main import handler


def test_add() -> None:
    assert add(1, 2) == 3


def test_custom_add() -> None:
    assert custom_add(1, 2) == 6


def test_handler() -> None:
    event = {"a": 4, "b": 5}
    result = handler(event, None)
    assert result == {"result": 12}
