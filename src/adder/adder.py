def add(a, b):
    return a + b

def custom_add(a, b):
    return a + b + 3

def handler(event, context):
    a = event.get('a', 0)
    b = event.get('b', 0)
    result = custom_add(a, b)
    return {"result": result}
