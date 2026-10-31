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

- The ChocoPy Language Manual and Reference (sections 3 and 4) and the PA1
  specification.
- The JFlex user manual (lexical states, `yypushback`, `<<EOF>>`) and the CUP
  manual (precedence declarations, `%prec`, the `error` token and how CUP
  re-synchronises after an error).
- The Python 3 documentation on lexical analysis, which the manual's
  INDENT/DEDENT algorithm is taken from.
- The staff reference implementation (`chocopy-ref.jar`), used as a test
  oracle through `--pass=r` and `chocopy.reference.ChocoPyLexer`.
- AI tools: we used Claude (Anthropic) as an assistant while writing and
  reviewing the lexer and parser, the test scripts in `tools/`, and this
  write-up. Every line was reviewed by the team, and all three of us can
  explain every part of the code.
- No collaboration with other groups.

### Time spent

About 32 hours in total for the whole team.

### Contributions

- **Mithulram Gunasekaran**: the JFlex lexer (`ChocoPy.jflex`), mainly the
  INDENT/DEDENT logic, end-of-file handling and string literals.
- **Mohamed Nuhuman Mohamed Nafeel**: the CUP grammar (`ChocoPy.cup`): the
  rules, operator precedence, AST construction and source locations.
- **Rajapaksha Mudiyanselage Dinodi Divyanjana Rajapaksha**: error recovery,
  the test infrastructure (`tools/`, `src/test/data/pa1/edge_cases/`),
  `good.py` / `bad.py`, and the bug report below.

All three of us reviewed each other's parts, and we debugged the location
mismatches together.

### How to test

```bash
mvn clean package
# provided samples (33) and our own edge cases (44): all pass
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/sample/
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/edge_cases/
# differential testing against the reference on random programs
python3 tools/fuzz.py /tmp/fuzz 500 7
python3 tools/difftest.py /tmp/fuzz
python3 tools/recovery_quality.py /tmp/fuzz 200
```

`tools/difftest.py` applies the grading rule of spec section 6.2.1: for a
valid program the whole AST must equal the reference's, and for an invalid
one the first error must be at the same location. In our final run on
3,511 files (samples, edge cases, probes, and random programs, half valid
and half with a random defect), every result matched the reference.

### Question 1: How do we emit INDENT and DEDENT tokens?

*Core code: `src/main/jflex/chocopy/pa1/ChocoPy.jflex`, lines 194-240
(`processIndentation`), the line-start rules at lines 322-342, and the
`<<EOF>>` rule at lines 425-446.*

The lexer has two states. `YYINITIAL` means "at the start of a physical
line" and `CODE` means "inside a logical line". In `YYINITIAL`, a line that
holds only whitespace and/or a comment is matched as a whole and thrown away,
so blank lines never produce tokens. A real line is matched by
`{WhiteSpace}* [^ \t\r\n#]`: its leading whitespace plus its first real
character. We match that character so the match can never be empty, and give
it back right away with `yypushback(1)`. `processIndentation` then measures
the whitespace (a tab jumps to the next multiple of 8) and compares the width
with the top of a stack of open levels, which starts as `[0]`. If the width is
equal, nothing is emitted and we switch to `CODE`. If it is larger, the width
is pushed and one INDENT is returned.

The tricky case is a dedent that closes several blocks at once. A JFlex action
can only return one token. So we pop one level, build the DEDENT, and push the
whole whitespace back into the input with `yypushback(yylength())`. On the
next call the lexer matches the same whitespace again, compares it with the
smaller stack, and emits the next DEDENT, until the levels agree. We need no
token queue, and the state lives entirely in the stack. If the stack drops
below the line's width without ever equalling it (levels 0,4,8 and a line at
2), the dedent is inconsistent. We emit an `UNRECOGNIZED` token, so that the
parser reports a syntax error, and treat the line as belonging to the
enclosing level (opening a new level here would leave an INDENT/DEDENT
pair behind that causes a second, misleading error). At end of file, the `<<EOF>>` rule first
emits the NEWLINE that a final line without a line break is missing. It then
emits one DEDENT per call until the stack is back to `[0]`, and finally EOF.

We also had to match the reference's *locations*, because the AST takes block
ends from these tokens. A DEDENT spans the leading whitespace of the line that
closes the block ([19,1,19,8] for 8 spaces). Tokens invented at end of file
move one column to the right each (see the bug report).

### Question 2: What was the hardest language feature (besides indentation)?

*Core code: `src/main/cup/chocopy/pa1/ChocoPy.cup`, lines 552-626
(`block`, `stmt`, the `*_header` rules and `elif_else`), together with the
precedence table at lines 303-311.*

The hardest part was `if`/`elif`/`else`, and more precisely making its AST
*identical* to the reference's, locations included. The AST has no "elif":
`if a: X elif b: Y else: Z` has to become `IfStmt(a, X, [IfStmt(b, Y, Z)])`.
We build this with the right-recursive rule `elif_else`. Each `elif` returns
a one-element list containing a nested `IfStmt`, so a chain of n elifs nests
n levels deep without any post-processing.

What made it hard was the source locations. An `IfStmt` does not end at its
last statement. It ends at the DEDENT that closes its last block, and a
nested elif ends there too. At first we chose the end based on whether the
else-list was empty. That broke on `else: pass`: `pass` creates no AST node,
so the list is empty, yet the reference still ends the statement at the
else-block's DEDENT. Our random tester found this. The fix was to split the
rule into "with" and "without" an elif/else part, so the end location comes
from a *grammar symbol* (`restxright`) rather than from list contents. The
same lesson applied to `Program`: a program that starts with `pass` starts at
that `pass` token, even though no node exists for it.

A close second was the `expr`/`cexpr` split combined with CUP precedence
declarations. Comparisons are `nonassoc` (so `a < b < c` is an error).
`not`, `and`, `or` and `if-else` only work on `expr`, which makes
`True == not False` an error as the manual requires. Unary minus gets its own
level through `%prec UMINUS`. The grammar builds with zero conflicts.

### Error recovery

Recovery works in three layers (summarised at the top of `ChocoPy.cup`):

1. **List-level `error` rules** on top-level declarations, statements,
   block/function-body statements and class members. They live in separate
   nonterminals on purpose: two `error` rules that are live in the same
   parser state would be a reduce/reduce conflict.
2. **Anchored rules** for the common mistakes. A bad initial value
   (`x:int = 1 + 2`) skips to the line's NEWLINE and stays in declaration
   mode (line 511). A broken `class`/`def`/`if`/`elif`/`while`/`for`
   header skips to its NEWLINE, and then parses the indented body if one
   follows (lines 384-385, 434-435, 583-589, 623-625). Without these
   rules, recovery resumed on leftover tokens as a *statement*, and every
   later declaration failed too. We anchor only on NEWLINE: our first
   version anchored on the header's colon, and when that colon never came,
   CUP searched to the end of the file and gave up parsing completely.
   The normal headers are separate nonterminals (`if_header` …), so once a
   header is reduced, a later error cannot fall back into its recovery
   rule.
3. **Default reductions in consistent states** (`enableDefaultReductions`,
   lines 88-123), as Bison does by default. Without them, in
   `z = 5` followed by `lambda = 5`, the error was detected *before*
   `z = 5 NEWLINE` was reduced to a statement, and recovery threw that
   correct statement away (the reference still does this). CUP offers this
   as the `-compact_red` option, but that is set in `pom.xml`, which we
   may not edit, so we patch the action table in `init with`.

None of this can move the first reported error. `error` never appears in
the input, so the set of valid token sequences is unchanged, and default
reductions consume no input. We measured the effect with
`tools/recovery_quality.py`, which puts exactly one defect into each of
346 valid programs (two independent random corpora):

| parser    | exactly one error reported | average errors per mistake | parses that gave up |
|-----------|----------------------------|----------------------------|---------------------|
| reference | 45.1 %                     | 2.01                       | 3                   |
| ours      | 74.6 %                     | 1.37                       | 0                   |

We also tried CUP's `error_sync_size` (1, 2 and the default 3). The
default gave the fewest cascading errors, so we kept it.

### Bug report (reference implementation)

1. **Inconsistent dedent leaves INDENT/DEDENT unbalanced.** Input:

   ```python
   if a:
       if b:
           c = 1
     d = 2
   e = 3
   ```

   The reference emits `DEDENT, UNRECOGNIZED, INDENT` on line 4. It pops only
   one level (8), then pushes 2 on top of 4, so the stack is no longer
   strictly increasing (manual 3.1.5). The program ends up with 3 INDENTs but
   only 2 DEDENTs, and the reference reports a second, bogus error
   `Parse error near token EOF` at 6:1. Expected: only the error at 4:1. The
   lexer should pop every level larger than 2 before it reports the bad
   indentation (our lexer does this).

2. **DEDENTs at end of file get made-up, increasing columns.** For
   `if a:\n  if b:\n    if c:\n      d\n`, the three DEDENTs at EOF are at
   (5,1), (5,2) and (5,3). So the three nested `IfStmt`s end at [5,1], [5,2]
   and [5,3], although no source text exists at those columns, and an outer
   block "ends after" its inner block. Expected: all at (5,1). The text of
   these tokens is also stale: an error on one prints
   `Parse error near token DEDENT: x` (the `x` is left over from an earlier
   token). We copied the column behaviour so that our ASTs match.

3. **String literals may span lines, and their end location is wrong.** The
   reference matches a string up to the next `"`, even on a later line, and
   only then rejects it as UNRECOGNIZED. A missing closing quote can
   therefore swallow several lines into one token. That token's end location
   is computed as start column + length on the *start* line, e.g.
   `[18,9,18,14]` for a token that really ends on line 19. Expected: stop at
   the end of the line (like Python's "unterminated string literal"), or at
   least report the right end line.

## Acknowledgments

This starter code is adapted from the work of the **ChocoPy team**
(see [this repository](https://github.com/cs164berkeley/pa1-chocopy-parser)). For more information, visit [ChocoPy.org](https://chocopy.org/).


