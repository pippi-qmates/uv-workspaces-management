from adder.main import add, custom_add


def test_add() -> None:
    assert add(1, 2) == 3


def test_custom_add() -> None:
    assert custom_add(1, 2) == 6
