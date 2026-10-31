#!/usr/bin/env bash
# Build submission/pa1_group_5.zip exactly as the spec asks (section 8):
# `mvn clean`, no target/, no .git, named pa1_group_<ID>.zip.
# Then unzip it into an empty temp folder, build it there and run the
# sample tests, so we know the uploaded file works on its own.
#
# Usage (from the repository root):  bash scripts/make_submission.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP="$ROOT/submission/pa1_group_5.zip"
CP_SEP=":"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CP_SEP=";" ;; esac

echo "== 1/3 cleaning the project"
(cd "$ROOT/chocopy-pa1" && mvn -q clean)
find "$ROOT/chocopy-pa1" \( -name "__pycache__" -o -name ".DS_Store" \) -prune -exec rm -rf {} +

echo "== 2/3 zipping"
mkdir -p "$ROOT/submission"
rm -f "$ZIP"
(cd "$ROOT" && zip -qr "$ZIP" chocopy-pa1 -x '*/.git/*' '*.DS_Store' '*/target/*' '*/__pycache__/*')
echo "   $ZIP ($(du -h "$ZIP" | cut -f1))"

echo "== 3/3 testing the zip from a clean unzip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(cd "$TMP" && unzip -q "$ZIP")
cd "$TMP/chocopy-pa1"
mvn -q clean package > /dev/null
CP="chocopy-ref.jar${CP_SEP}target/assignment.jar"
RESULT="$(java -cp "$CP" chocopy.ChocoPy --pass=s --dir src/test/data/pa1/sample --test 2>&1 | tail -1)"
GOOD="$(java -cp "$CP" chocopy.ChocoPy --pass=s src/test/data/pa1/student_contributed/good.py 2>&1 | grep -c 'Parse error' || true)"
BAD="$(java -cp "$CP" chocopy.ChocoPy --pass=s src/test/data/pa1/student_contributed/bad.py 2>&1 | grep -c 'Parse error' || true)"
echo "   samples: $RESULT"
echo "   good.py errors: $GOOD (expected 0) · bad.py errors: $BAD (expected >= 2)"

case "$RESULT" in
  *"0 failed"*) ;;
  *) echo "FAILED: sample tests"; exit 1 ;;
esac
[ "$GOOD" = "0" ] || { echo "FAILED: good.py has errors"; exit 1; }
[ "$BAD" -ge 2 ] || { echo "FAILED: bad.py needs at least two errors"; exit 1; }

# Rebuild the working copy so the demo still has target/assignment.jar.
(cd "$ROOT/chocopy-pa1" && mvn -q clean package > /dev/null)
echo "OK - upload submission/pa1_group_5.zip to Stud.IP (SubmissionsDir)"
