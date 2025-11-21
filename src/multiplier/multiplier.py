def multiply(a, b):
    return a * b

def handler(event, context):
    a = event.get('a', 0)
    b = event.get('b', 0)
    result = multiply(a, b)
    return {"result": result}
