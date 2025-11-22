from typing import Any


def multiply(a: int, b: int) -> int:
    return a * b


def handler(event: dict[str, Any], _context: Any) -> dict[str, int]:
    a: int = event.get("a", 0)
    b: int = event.get("b", 0)
    result = multiply(a, b)
    return {"result": result}
