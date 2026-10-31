#!/usr/bin/env bash
# Live demo for the PA1 presentation (group 5).
#
# Run from anywhere:   bash PA1/demo/demo.sh
# Each step prints the command it is about to run and waits for ENTER, so the
# presenter controls the pace. Type "s" + ENTER to skip a step.
#
# Prerequisite (do it BEFORE the talk, it needs the network the first time):
#   cd PA1/chocopy-pa1 && mvn clean package

set -u
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$DEMO_DIR/../chocopy-pa1" && pwd)"
SEP=":"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) SEP=";" ;; esac
CP="chocopy-ref.jar${SEP}target/assignment.jar"
cd "$PROJECT"

bold() { printf '\n\033[1;33m%s\033[0m\n' "$*"; }
step() {
    bold "== $1"
    shift
    printf '\033[36m$ %s\033[0m' "$*"
    read -r answer
    [ "$answer" = "s" ] && return
    eval "$@"
}

if [ ! -f target/assignment.jar ]; then
    echo "target/assignment.jar is missing - run 'mvn clean package' in $PROJECT first."
    exit 1
fi

step "1. All provided sample tests (33) and our edge cases (44)" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/sample --test 2>&1 | tail -1;" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/edge_cases --test 2>&1 | tail -1"

step "2. Indentation: line 6 closes two blocks at once -> two DEDENTs (yypushback loop)" \
    "cat -n \"$DEMO_DIR/1_indentation.py\";" \
    "java -cp \"$CP\" chocopy.pa1.ChocoPyLexer \"$DEMO_DIR/1_indentation.py\" 2>/dev/null | grep -E 'INDENT|DEDENT'"

step "3. elif becomes a nested IfStmt in the else-body (and 'else: pass' is an empty list)" \
    "cat -n \"$DEMO_DIR/2_ast.py\";" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=s --out /tmp/pa1_demo.json \"$DEMO_DIR/2_ast.py\" >/dev/null 2>&1;" \
    "python3 tools/ast_tree.py /tmp/pa1_demo.json"

step "4. Precedence: unary minus, member/index, not/or, if-else" \
    "cat \"$DEMO_DIR/3_precedence.py\";" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=s --out /tmp/pa1_demo.json \"$DEMO_DIR/3_precedence.py\" >/dev/null 2>&1;" \
    "python3 tools/ast_tree.py /tmp/pa1_demo.json"

step "5. Same AST as the reference? (the grader's comparison rule)" \
    "python3 tools/difftest.py \"$DEMO_DIR\""

step "6. Error recovery: ours (one error per mistake) ..." \
    "cat -n \"$DEMO_DIR/4_recovery.py\";" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=s \"$DEMO_DIR/4_recovery.py\" 2>&1 | grep 'Parse error'"

step "   ... versus the reference (cascading errors)" \
    "java -cp \"$CP\" chocopy.ChocoPy --pass=r \"$DEMO_DIR/4_recovery.py\" 2>&1 | grep 'Parse error'"

step "   ... and the statement before 'lambda' (z = 5, line 10): kept by us, lost by the reference" \
    "for pass_ in s r; do" \
    "  java -cp \"$CP\" chocopy.ChocoPy --pass=\$pass_ --out /tmp/pa1_demo.json \"$DEMO_DIR/4_recovery.py\" >/dev/null 2>&1;" \
    "  printf '%-10s statements on lines ' \$( [ \$pass_ = s ] && echo ours || echo reference );" \
    "  python3 -c \"import json; print([s['location'][0] for s in json.load(open('/tmp/pa1_demo.json'))['statements']])\";" \
    "done"

step "7. Reference bug: bad dedent -> unbalanced INDENT/DEDENT -> bogus EOF error" \
    "cat -n \"$DEMO_DIR/5_reference_bug.py\";" \
    "echo '--- reference:'; java -cp \"$CP\" chocopy.ChocoPy --pass=r \"$DEMO_DIR/5_reference_bug.py\" 2>&1 | grep 'Parse error';" \
    "echo '--- ours:';      java -cp \"$CP\" chocopy.ChocoPy --pass=s \"$DEMO_DIR/5_reference_bug.py\" 2>&1 | grep 'Parse error'"

step "8. Differential fuzzing: 50 random valid programs + 50 mutants vs the reference" \
    "python3 tools/fuzz.py /tmp/pa1_fuzz 50 \$RANDOM && python3 tools/difftest.py /tmp/pa1_fuzz"

bold "Demo finished."
