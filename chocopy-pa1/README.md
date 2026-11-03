# Programming Assignment 1

[PA1 Specification]: https://studip.uni-passau.de/studip/dispatch.php/course/files?cid=1158ee3975665902d07585a824234cb1

[ChocoPy Language Manual and Reference]: https://studip.uni-passau.de/studip/dispatch.php/course/files?cid=1158ee3975665902d07585a824234cb1

Note: Users running Windows should replace the colon (`:`) with
a semicolon (`;`) in the classpath argument for
all commands listed below.

## Getting started

Run the following command to generate and compile your parser, and then run all the provided tests:

```bash
mvn clean package

java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/sample/
```

In the starter code, only one test should pass. Your objective is to build a parser that passes all the provided tests and meets the assignment specifications.

To manually observe the output of your parser when run on a given input ChocoPy program, run the following command (replace the last argument to change the input file):

```bash
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s src/test/data/pa1/sample/expr_plus.py
```

You can check the output produced by the staff-provided reference implementation on the same input file, as follows:

```bash
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=r src/test/data/pa1/sample/expr_plus.py
```

Try this with another input file as well, such as `src/test/data/pa1/sample/coverage.py`, to see what happens when the results disagree.

## Assignment specifications

See the [PA1 Specification][]
for a detailed specification of the assignment.

Refer to the [ChocoPy Language Manual and Reference][]
for the specification of the ChocoPy language.

## Submission write-up

### Team (group 5)

- Mithulram Gunasekaran
- Mohamed Nuhuman Mohamed Nafeel
- Rajapaksha Mudiyanselage Dinodi Divyanjana Rajapaksha

### Acknowledgements

We mostly worked from the PA1 spec and the ChocoPy manual (sections 3 and 4),
plus the JFlex and CUP manuals. For the indentation rules we also looked at the
"Lexical analysis" page of the Python 3 docs, since the manual's algorithm comes
from there. We used the reference implementation (`chocopy-ref.jar`) a lot, both
`--pass=r` and `chocopy.reference.ChocoPyLexer`, to find out what output is
expected.

### Time spent

About 32 hours for the whole team.

### Contributions

- Mithulram Gunasekaran: the lexer (`ChocoPy.jflex`), mostly INDENT/DEDENT,
  end of file and string literals.
- Mohamed Nuhuman Mohamed Nafeel: the grammar (`ChocoPy.cup`), i.e. the rules,
  precedence, building the AST and getting the locations right.
- Rajapaksha Mudiyanselage Dinodi Divyanjana Rajapaksha: error recovery, the
  test scripts (`tools/`, `src/test/data/pa1/edge_cases/`), `good.py`/`bad.py`
  and the bug report.

We reviewed each other's parts, and the location bugs we mostly debugged
together.

### How to test

```bash
mvn clean package
# the 33 provided samples and our 44 edge cases
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/sample/
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/edge_cases/
# compare with the reference on random programs
python3 tools/fuzz.py /tmp/fuzz 500 7
python3 tools/difftest.py /tmp/fuzz
python3 tools/recovery_quality.py /tmp/fuzz 200
```

`tools/difftest.py` compares our output with the reference the same way the
spec says grading works (section 6.2.1): for a valid program the whole AST has
to be equal, for an invalid one only the location of the first error. Our last
run had 3,511 files (samples, edge cases and random programs, about half of them
with a random mistake put in) and all of them matched.

### Question 1: How do we emit INDENT and DEDENT tokens?

*Main code: `src/main/jflex/chocopy/pa1/ChocoPy.jflex`, `processIndentation`
(lines 175-220), the rules for the start of a line (lines 296-316) and the
`<<EOF>>` rule (lines 399-419).*

The lexer has two states. `YYINITIAL` means we are at the start of a line and
`CODE` means we are inside one. In `YYINITIAL`, lines with only whitespace or a
comment are matched completely and dropped, so they never produce tokens. For a
real line the rule `{WhiteSpace}* [^ \t\r\n#]` (line 309) matches the leading
whitespace plus the first real character. We need that extra character because
JFlex can't fire on an empty match, which is what a line with no indentation
would be. We give the character back with `yypushback(1)` right away.
`processIndentation` then works out the width (a tab jumps to the next multiple
of 8) and compares it with the top of the indentation stack, which starts as
`[0]`. Same width: nothing happens and we switch to `CODE`. Bigger: we push it
and return INDENT.

The harder case is a line that closes several blocks at once, because a JFlex
action can only return one token. We pop one level, return one DEDENT, and push
the whole whitespace back with `yypushback(yylength())`. On the next call the
lexer reads the same whitespace again, compares it with the smaller stack and
returns the next DEDENT, until the levels match. So we didn't need a token
queue; the stack is the only state. If we pop past the line's width without
ever hitting it (levels 0, 4, 8 and then a line at 2), the indentation is
inconsistent. Then we return an `UNRECOGNIZED` token so the parser reports an
error, and treat the line as part of the level we reached. At end of file,
`<<EOF>>` first gives the NEWLINE that a last line without a line break is
missing, then one DEDENT per call until the stack is back to `[0]`, then EOF.

The locations took longer than the logic. The AST takes the end of a block from
its DEDENT, so we had to place DEDENTs where the reference does: over the
leading whitespace of the line that closes the block (`[19,1,19,8]` for 8
spaces). Tokens made up at EOF also move one column right each time, like in
the reference (see the bug report).

### Question 2: What was the hardest feature apart from indentation?

*Main code: `src/main/cup/chocopy/pa1/ChocoPy.cup`, lines 518-588 (`block`,
`stmt`, the `*_header` rules and `elif_else`) and the precedence table at lines
283-291.*

For us it was `if`/`elif`/`else`, or really getting its AST exactly like the
reference including the locations. The AST has no elif, so
`if a: X elif b: Y else: Z` has to turn into `IfStmt(a, X, [IfStmt(b, Y, Z)])`.
We do that with the right-recursive rule `elif_else`: each `elif` gives a list
with one nested `IfStmt`, and the nesting falls out of the recursion.

The locations were the hard part. An `IfStmt` ends at the DEDENT after its last
block, not at its last statement, and a nested elif ends there as well. At first
we chose the end depending on whether the else-list was empty. That broke for
`else: pass`, because `pass` has no AST node, so the list is empty but the
reference still ends the statement at the else-block's DEDENT. Our random tests
found this one after we had already passed all the samples. We fixed it by
splitting the rule into a version with and a version without the elif/else
part, so the end always comes from a grammar symbol (`restxright`) and never
from a list. The same problem showed up for `Program`: a program that starts
with `pass` still starts at that `pass`.

A close second was getting `expr`/`cexpr` and the precedence declarations right.
Comparisons are `nonassoc` so `a < b < c` is an error, `not`/`and`/`or`/`if-else`
only take `expr` so `True == not False` is an error like the manual wants, and
unary minus has its own level through `%prec UMINUS`. The grammar has no
conflicts.

### Error recovery

Recovery ended up in three parts (there's a short summary at the top of
`ChocoPy.cup` too):

1. Every list has an `error` alternative: top-level declarations, statements,
   block and function-body statements, class members. They are separate
   nonterminals because two `error` rules that are both live in the same state
   give a reduce/reduce conflict.
2. Extra rules for the mistakes people actually make. A value that isn't a
   literal (`x:int = 1 + 2`) skips to the end of the line and we stay in
   declaration mode (line 478). A broken `class`/`def`/`if`/`elif`/`while`/`for`
   header skips to the end of its line and then parses the indented body if
   there is one (lines 356-357, 405-406, 547-553, 585-587). Before this, recovery
   continued on leftover tokens as a statement, and every declaration after that
   failed as well. We first used the colon as the place to resume, but when the
   colon never came CUP went to the end of the file and gave up completely, so
   now we always resume at NEWLINE. The normal headers are their own
   nonterminals (`if_header` etc.) so a later error can't end up in a header
   rule by accident.
3. Default reductions in consistent states (`enableDefaultReductions`, lines
   83-118), which Bison does by default. Without them, in `z = 5` followed by
   `lambda = 5`, CUP reported the error before reducing `z = 5 NEWLINE` to a
   statement, and recovery then threw that correct statement away (the
   reference still does this). CUP has a `-compact_red` option for this, but
   it's set in `pom.xml`, which we are not allowed to change, so we patch the
   parse table in `init with` instead.

None of this can change where the first error is reported, because `error`
never shows up in the real input and reductions don't read any input. To see
whether the changes actually helped, we wrote `tools/recovery_quality.py`. It
puts one mistake into each of 346 valid programs:

| parser    | exactly one error reported | errors per mistake (avg) | parses that gave up |
|-----------|----------------------------|--------------------------|---------------------|
| reference | 45.1 %                     | 2.01                     | 3                   |
| ours      | 74.6 %                     | 1.37                     | 0                   |

We also tried CUP's `error_sync_size` with 1 and 2 instead of the default 3.
Both gave more follow-up errors, so we left it at 3.

### Bug report (reference implementation)

1. **Unbalanced INDENT/DEDENT after a bad dedent.** Input:

   ```python
   if a:
       if b:
           c = 1
     d = 2
   e = 3
   ```

   On line 4 the reference emits `DEDENT, UNRECOGNIZED, INDENT`. It pops only
   one level (8) and then pushes 2 on top of 4, so the stack isn't increasing
   any more (manual 3.1.5). In the end there are 3 INDENTs but only 2 DEDENTs,
   and the reference reports a second error `Parse error near token EOF` at 6:1
   that shouldn't be there. Expected: only the error at 4:1. It should pop every
   level above 2 before reporting the bad indentation, which is what our lexer
   does.

2. **DEDENTs at end of file get made-up columns.** For
   `if a:\n  if b:\n    if c:\n      d\n` the three DEDENTs at EOF are at (5,1),
   (5,2) and (5,3), so the three nested `IfStmt`s end at [5,1], [5,2] and [5,3]
   even though there is no text there, and the outer block ends after the inner
   one. We'd expect all of them at (5,1). The token text is also stale: an error
   on one of them prints `Parse error near token DEDENT: x`. We copied the column
   behaviour anyway so our ASTs match.

3. **Strings can go over several lines, with a wrong end location.** The
   reference matches a string up to the next `"`, even if that is lines later,
   and only then rejects it as UNRECOGNIZED. So one missing quote can swallow
   several lines. The end location is also computed as start column + length on
   the start line, e.g. `[18,9,18,14]` for a token that really ends on line 19.
   We'd expect the string to stop at the end of the line (like Python's
   "unterminated string literal"), or at least the correct end line.

## Acknowledgments

This starter code is adapted from the work of the **ChocoPy team**
(see [this repository](https://github.com/cs164berkeley/pa1-chocopy-parser)). For more information, visit [ChocoPy.org](https://chocopy.org/).


