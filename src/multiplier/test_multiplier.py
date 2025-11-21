from multiplier import multiply, handler

def test_multiply():
    assert multiply(2, 3) == 6

def test_handler():
    event = {'a': 4, 'b': 5}
    result = handler(event, None)
    assert result == {'result': 20}
