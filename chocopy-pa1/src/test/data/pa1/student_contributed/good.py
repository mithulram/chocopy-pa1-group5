# good.py: one program that touches (almost) every syntax rule of ChocoPy.
# It must parse without a single error.  Group 5, PA1.

# ---- Global variable definitions: every kind of literal and type ----------
count:int = 0
big:int = 2147483647            # the largest legal integer literal
name:str = "ChocoPy"
empty:str = ""
escaped:str = "She said \"hi\"\n\tand left \\ again"
flag:bool = True
other_flag:bool = False
nothing:object = None
grid:[[int]] = None             # nested list type
people:["Person"] = None        # IDSTRING (quoted class name) as a type

# ---- A function with parameters, a return type and a nested function -------
def tally(values:[int], limit:int) -> int:
    global count                # global declaration
    total:int = 0               # local variable definition

    def bump(amount:int) -> object:
        nonlocal total          # nonlocal declaration
        total = total + amount

    for value in values:        # for loop
        if value > limit:       # if / elif / else chain
            bump(limit)
        elif value < 0:
            pass
        elif value == 0:
            continue_ = 1       # identifiers may contain keywords
        else:
            bump(value)
    count = count + 1
    return total

# ---- A function with no parameters and no return type ------------------------
def nothing_to_do():
    pass

# ---- Classes: attributes, methods, inheritance, a pass-only class ----------
class Person(object):
    age:int = 0
    name:str = "anon"

    def __init__(self:"Person"):
        self.age = 1

    def greet(self:"Person", other:"Person") -> str:
        return "Hi " + other.name

    def is_older(self:"Person", other:"Person") -> bool:
        return self.age >= other.age and not (self is other)

class Student(Person):
    school:str = "Passau"

class Marker(object):
    pass

# ---- Statements and expressions ---------------------------------------------
p:Person = None                 # (declarations must come before statements)

p = Person()
q = Student()
a = b = c = 0                   # chained assignment
grid = [[1, 2], [3, 4], []]     # list literals, empty list
grid[0][1] = grid[1][0]         # index expression as an assignment target
p.age = q.age = 42              # member expressions as targets

# Arithmetic and precedence:  -  binds tighter than  *  tighter than  +
a = -b * c + 10 // 3 % 2 - --a
# Comparisons (non-associative) and the logical operators
flag = a < b or b <= c and not c > a
flag = (a == b) != (b != c)
flag = p is None or not p is q
# Conditional expressions, right-associative
a = 1 if flag else 2 if other_flag else 3

# Calls, method calls, chained member/index access
print(tally([1, -2, 0, 99], 50))
print(p.greet(q).upper())
print(len(grid[1]) + grid[0][0])
print("ok" if p.is_older(q) else "not ok")

# while loop with a nested if
while count < 3:
    count = count + 1
    if count == 2:
        nothing_to_do()

# A block that ends exactly at end of file, several levels deep
for name in ["a", "b"]:
    while flag:
        if not flag:
            flag = False
        else:
            flag = not flag
