from typing import Any, Dict

from adder.custom.add import custom_add


def handler(event: Dict[str, Any], context: Any) -> Dict[str, int]:
    a = event.get("a", 0)
    b = event.get("b", 0)
    result = custom_add(a, b)
    return {"result": result}
