# bad.py: syntax errors, and how the parser recovers from them.
# Each numbered case is a separate mistake. After every one, the parser
# should get back on track and still parse the lines that follow.
# Expected: exactly one error per case, and no cascading errors.
# (The statement cases are followed by a correct line: after an error, CUP
# resumes only once 3 tokens in a row parse cleanly.)
# Group 5, PA1.

# (1) Variable definition: the initial value must be a literal.
x:int = 1 + 2
y:int = 3

# (2) Function definition with a parameter that has no type.
def broken(a, b:int) -> int:
    return b

# (3) Class definition without a superclass.
class Thing:
    pass

# (4) A good function after the broken declarations is still parsed.
def fine(n:int) -> int:
    return n

# (5) Statement: an unrecognized character (&&) in an expression.
ok = True && False
z = 4

# (6) Statement: comparisons cannot be chained in ChocoPy.
check = 1 < 2 < 3
z = 5

# (7) Statement: a Python keyword that ChocoPy reserves.
lambda = 5
z = 6

# (8) Statement: a string with an illegal escape sequence.
s = "C:\path"
z = 7

# (9) Bad indentation inside a block (unindent to an unknown level).
if z:
    if ok:
        z = 1
  z = 2
z = 8

# (10) Integer literal too large for 32 bits.
big = 2147483648

# The parser must still reach the end of the file.
print(fine(z))
