def outer() -> int:
    x:int = 0
    def inner(y: int) -> object:
        nonlocal x
        global g
        z:[int] = None
        x = y
    inner(1)
    return x
