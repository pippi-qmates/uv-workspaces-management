from typing import Any, Dict


def multiply(a: int, b: int) -> int:
    return a * b


def handler(event: Dict[str, Any], context: Any) -> Dict[str, int]:
    a = event.get("a", 0)
    b = event.get("b", 0)
    result = multiply(a, b)
    return {"result": result}
