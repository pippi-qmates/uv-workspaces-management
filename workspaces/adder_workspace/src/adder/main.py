from typing import Any, Dict


def add(a: int, b: int) -> int:
    return a + b


def custom_add(a: int, b: int) -> int:
    return a + b + 3


def handler(event: Dict[str, Any], context: Any) -> Dict[str, int]:
    a = event.get("a", 0)
    b = event.get("b", 0)
    result = custom_add(a, b)
    return {"result": result}
