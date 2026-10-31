#!/usr/bin/env python3
"""Random ChocoPy program generator, used for differential testing.

It writes N random *syntactically valid* programs (built from the grammar in
Figure 3 of the manual), plus N *mutated* copies with one random defect each
(a deleted/duplicated/swapped token, a broken indent, a stray character...).
Run tools/difftest.py on the output directory afterwards.

Usage:  python3 tools/fuzz.py <out_dir> [count] [seed]
"""
import os
import random
import sys

NAMES = ["x", "y", "foo", "bar_1", "_tmp", "classic", "iffy", "nonee", "a", "b"]
TYPES = ["int", "str", "bool", "object", '"Foo"', "[int]", "[[str]]"]
BIN_OPS = ["+", "-", "*", "//", "%", "==", "!=", "<", ">", "<=", ">=", "is"]
STRINGS = ['"hi"', '""', '"a b"', '"He\\"ll\\"o"', '"tab\\there"', '"x\\\\y"',
           '"Foo"', '"line\\n"', '"#not a comment"']


class Gen:
    def __init__(self, rnd):
        self.r = rnd

    def pick(self, xs):
        return self.r.choice(xs)

    # ---------------- expressions ----------------
    def literal(self):
        return self.pick(["None", "True", "False", str(self.r.randint(0, 2147483647)),
                          "0", "7", self.pick(STRINGS)])

    def cexpr(self, d):
        if d <= 0:
            return self.pick([self.pick(NAMES), self.literal()])
        k = self.r.randint(0, 9)
        if k == 0:
            return "[" + ", ".join(self.expr(d - 1) for _ in range(self.r.randint(0, 3))) + "]"
        if k == 1:
            return "(" + self.expr(d - 1) + ")"
        if k == 2:
            return self.cexpr(d - 1) + "." + self.pick(NAMES)
        if k == 3:
            return self.cexpr(d - 1) + "[" + self.expr(d - 1) + "]"
        if k == 4:
            return self.cexpr(d - 1) + "." + self.pick(NAMES) + "(" + self.args(d) + ")"
        if k == 5:
            return self.pick(NAMES) + "(" + self.args(d) + ")"
        if k == 6:
            return "-" + self.cexpr(d - 1)
        if k in (7, 8):
            # Comparisons are non-associative (a < b < c is an error), so a
            # comparison is always wrapped in parentheses. That keeps it from
            # chaining with a neighbouring comparison.
            op = self.pick(BIN_OPS)
            text = self.cexpr(d - 1) + " " + op + " " + self.cexpr(d - 1)
            return "(" + text + ")" if op in BIN_OPS[5:] else text
        return self.pick([self.pick(NAMES), self.literal()])

    def args(self, d):
        return ", ".join(self.expr(d - 1) for _ in range(self.r.randint(0, 3)))

    def expr(self, d):
        if d <= 0:
            return self.cexpr(0)
        k = self.r.randint(0, 6)
        if k == 0:
            return "not " + self.expr(d - 1)
        if k == 1:
            return self.expr(d - 1) + " and " + self.expr(d - 1)
        if k == 2:
            return self.expr(d - 1) + " or " + self.expr(d - 1)
        if k == 3:
            return self.expr(d - 1) + " if " + self.expr(d - 1) + " else " + self.expr(d - 1)
        return self.cexpr(d)

    def primary(self, d):
        """An expression that may be followed by .name or [index] and still
        be a valid assignment target (so not "-x" or "a + b")."""
        k = self.r.randint(0, 4) if d > 0 else 0
        if k == 0:
            return self.pick(NAMES)
        if k == 1:
            return self.pick(NAMES) + "(" + self.args(d) + ")"
        if k == 2:
            return "(" + self.expr(d - 1) + ")"
        if k == 3:
            return self.primary(d - 1) + "." + self.pick(NAMES)
        return self.primary(d - 1) + "[" + self.expr(d - 1) + "]"

    def target(self, d):
        k = self.r.randint(0, 2)
        if k == 0:
            return self.pick(NAMES)
        if k == 1:
            return self.primary(d - 1) + "." + self.pick(NAMES)
        return self.primary(d - 1) + "[" + self.expr(d - 1) + "]"

    # ---------------- statements ----------------
    def ws(self, level):
        # mix spaces and tabs; a tab here always equals 8 columns
        return self.pick(["    " * level, "\t" * (level // 2) + "    " * (level % 2)]) \
            if level else ""

    def junk_lines(self, level):
        """Blank lines and comment-only lines, which must be ignored."""
        out = []
        for _ in range(self.r.choice([0, 0, 0, 1, 2])):
            out.append(self.pick(["", "   ", "\t", "# note", "        # deep comment",
                                  "  # odd comment"]))
        return out

    def simple_stmt(self, d):
        k = self.r.randint(0, 5)
        if k == 0:
            return "pass"
        if k == 1:
            return "return" + ("" if self.r.random() < 0.3 else " " + self.expr(d))
        if k in (2, 3):
            return " = ".join(self.target(d) for _ in range(self.r.randint(1, 3))) + " = " + self.expr(d)
        return self.expr(d)

    def block(self, level, d):
        lines = []
        for _ in range(self.r.randint(1, 3)):
            lines += self.stmt(level, d - 1)
        return lines

    def stmt(self, level, d):
        pre = self.ws(level)
        tail = self.pick(["", "", "", "  # trailing comment"])
        lines = self.junk_lines(level)
        k = self.r.randint(0, 9) if d > 0 else 9
        if k == 0:
            lines.append(pre + "if " + self.expr(2) + ":" + tail)
            lines += self.block(level + 1, d)
            for _ in range(self.r.randint(0, 2)):
                lines.append(pre + "elif " + self.expr(2) + ":")
                lines += self.block(level + 1, d)
            if self.r.random() < 0.5:
                lines.append(pre + "else:")
                lines += self.block(level + 1, d)
        elif k == 1:
            lines.append(pre + "while " + self.expr(2) + ":")
            lines += self.block(level + 1, d)
        elif k == 2:
            lines.append(pre + "for " + self.pick(NAMES) + " in " + self.expr(2) + ":")
            lines += self.block(level + 1, d)
        else:
            lines.append(pre + self.simple_stmt(2) + tail)
        return lines

    # ---------------- declarations ----------------
    def var_def(self, level):
        return [self.ws(level) + self.pick(NAMES) + ":" + self.pick(TYPES) + " = " + self.literal()]

    def func_def(self, level, d):
        pre = self.ws(level)
        params = ", ".join(self.pick(NAMES) + ":" + self.pick(TYPES)
                           for _ in range(self.r.randint(0, 3)))
        ret = "" if self.r.random() < 0.4 else " -> " + self.pick(TYPES)
        lines = [pre + "def " + self.pick(NAMES) + "(" + params + ")" + ret + ":"]
        for _ in range(self.r.randint(0, 3)):
            k = self.r.randint(0, 3)
            if k == 0:
                lines.append(self.ws(level + 1) + "global " + self.pick(NAMES))
            elif k == 1:
                lines.append(self.ws(level + 1) + "nonlocal " + self.pick(NAMES))
            elif k == 2 and d > 0:
                lines += self.func_def(level + 1, d - 1)
            else:
                lines += self.var_def(level + 1)
        lines += self.block(level + 1, 2)
        return lines

    def class_def(self, level):
        lines = ["class " + self.pick(NAMES) + "(" + self.pick(NAMES) + "):"]
        if self.r.random() < 0.2:
            lines.append(self.ws(1) + "pass")
            return lines
        for _ in range(self.r.randint(1, 3)):
            lines += self.var_def(1) if self.r.random() < 0.5 else self.func_def(1, 1)
        return lines

    def program(self):
        lines = []
        for _ in range(self.r.randint(0, 3)):
            k = self.r.randint(0, 2)
            lines += self.var_def(0) if k == 0 else (self.func_def(0, 1) if k == 1 else self.class_def(0))
        for _ in range(self.r.randint(0, 4)):
            lines += self.stmt(0, 3)
        newline = self.pick(["\n", "\n", "\n", "\r\n", "\r"])
        text = newline.join(lines)
        if self.r.random() < 0.8:          # sometimes no trailing newline
            text += newline
        return text


def mutate(rnd, text):
    """Introduce one random defect into a program."""
    if not text:
        return "$"
    pos = rnd.randrange(len(text))
    k = rnd.randint(0, 7)
    if k == 0:                                   # delete a chunk
        return text[:pos] + text[pos + rnd.randint(1, 4):]
    if k == 1:                                   # insert a stray token
        return text[:pos] + rnd.choice([" = ", ":", "(", ")", "]", ",", " if ", " not ",
                                        "$", "&", "!", " lambda ", '"', " 99999999999 ",
                                        " == ", "  "]) + text[pos:]
    if k == 2:                                   # duplicate a chunk
        return text[:pos] + text[pos:pos + 5] + text[pos:]
    if k == 3:                                   # break the indentation of one line
        lines = text.split("\n")
        i = rnd.randrange(len(lines))
        lines[i] = rnd.choice([" ", "  ", "\t ", ""]) + lines[i].lstrip(" \t") \
            if rnd.random() < 0.5 else "   " + lines[i]
        return "\n".join(lines)
    if k == 4:                                   # swap two neighbouring words
        words = text.split(" ")
        if len(words) > 2:
            i = rnd.randrange(len(words) - 1)
            words[i], words[i + 1] = words[i + 1], words[i]
        return " ".join(words)
    if k == 5:                                   # illegal escape / char in string
        return text.replace('"hi"', rnd.choice(['"h\\i"', '"h\ti"', '"hé"']), 1) + "\n\"bad\\q\"\n"
    if k == 6:                                   # a keyword in the wrong place
        return text[:pos] + rnd.choice([" class ", " def ", " return ", " else ", " elif ",
                                        " pass ", " global x\n"]) + text[pos:]
    return text[:pos] + "\n" + text[pos:]       # split a line in two


def main():
    out_dir = sys.argv[1]
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 164
    rnd = random.Random(seed)
    os.makedirs(out_dir, exist_ok=True)
    gen = Gen(rnd)
    for i in range(count):
        program = gen.program()
        with open(os.path.join(out_dir, "good_%04d.py" % i), "w", newline="") as f:
            f.write(program)
        with open(os.path.join(out_dir, "mut_%04d.py" % i), "w", newline="") as f:
            f.write(mutate(rnd, program))


if __name__ == "__main__":
    main()
