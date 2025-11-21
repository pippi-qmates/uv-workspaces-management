from typing import Any

from lambdas.adder.custom.add import custom_add


def handler(event: dict[str, Any], _context: Any) -> dict[str, int]:
    a: int = event.get("a", 0)
    b: int = event.get("b", 0)
    result = custom_add(a, b)
    return {"result": result}
