from adder import add, custom_add

def test_add():
    assert add(1, 2) == 3

def test_custom_add():
    assert custom_add(1, 2) == 6
