def total(xs:[int]) -> int:
    s:int = 0
    for x in xs:
        if x > 0:
            s = s + x
    return s

print(total([1, -2, 3]))
