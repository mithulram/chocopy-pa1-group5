#!/usr/bin/env python3
"""Differential tester: compares our parser (--pass=s) with the reference
parser (--pass=r) on every .py file in the given directories.

Grading rule from the spec (section 6.2.1), which this script mirrors:
  * valid program   -> the whole JSON AST must be equal
  * invalid program -> only the location of the FIRST error must match

Usage (from the project root, after `mvn clean package`):
    python3 tools/difftest.py <dir-or-file> [...]
"""
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

CLASSPATH = "chocopy-ref.jar" + os.pathsep + "target/assignment.jar"


def parse(path, which):
    """Run one parser ('s' = ours, 'r' = reference) and return its JSON."""
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as out:
        out_path = out.name
    try:
        subprocess.run(["java", "-cp", CLASSPATH, "chocopy.ChocoPy",
                        "--pass=" + which, "--out", out_path, path],
                       capture_output=True, timeout=60)
        with open(out_path) as f:
            return json.load(f)
    except (ValueError, OSError):
        return None          # not valid JSON counts as a failure
    finally:
        os.unlink(out_path)


def first_error(ast):
    errors = ast["errors"]["errors"]
    return errors[0]["location"] if errors else None


def compare(path):
    ours, ref = parse(path, "s"), parse(path, "r")
    if ours is None:
        return "our output is not valid JSON"
    if ref is None:
        return None          # reference crashed: nothing to compare against
    if first_error(ref) is None:
        if ours != ref:
            return "AST differs"
    elif first_error(ours) != first_error(ref):
        return "first error at %s, reference at %s" % (first_error(ours), first_error(ref))
    return None


def main():
    files = []
    for arg in sys.argv[1:]:
        if os.path.isdir(arg):
            files += sorted(os.path.join(arg, f) for f in os.listdir(arg) if f.endswith(".py"))
        else:
            files.append(arg)
    failures = 0
    # Each comparison starts two JVMs, so run several comparisons at once.
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        results = list(pool.map(compare, files))
    for path, problem in zip(files, results):
        if problem:
            failures += 1
            print("FAIL %s: %s" % (path, problem))
    print("%d files, %d match the reference, %d differ" % (len(files), len(files) - failures, failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
