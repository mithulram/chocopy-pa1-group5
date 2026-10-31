#!/usr/bin/env python3
"""Measures how well a parser recovers from errors.

Each valid program from the fuzzer gets exactly ONE defect: a '$' inserted
into one random code line. An ideal parser then reports exactly 1 error and
loses nothing but the damaged line. For our parser (--pass=s) and the
reference (--pass=r) this script reports:
  * exactly-one  : % of programs where exactly one error was reported
  * avg errors   : average number of errors reported (ideal: 1.0)
  * kept         : % of the undamaged top-level declarations/statements
                   that are still in the AST
  * aborted      : programs where CUP's recovery failed completely and parsing
                   stopped ("Error recovery fails" in the --debug trace). This
                   should be 0. (An empty AST alone does not count: if a
                   program is a single statement and that statement is broken,
                   dropping it correctly leaves nothing.)

Usage: python3 tools/recovery_quality.py <dir with good_*.py> [limit]
"""
import glob, json, os, random, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

CP = "chocopy-ref.jar" + os.pathsep + "target/assignment.jar"

def ast(path, which):
    out = tempfile.mktemp(suffix=".json")
    subprocess.run(["java", "-cp", CP, "chocopy.ChocoPy", "--pass=" + which, "--out", out, path],
                   capture_output=True)
    with open(out) as f:
        d = json.load(f)
    os.unlink(out)
    return d

def aborted(path, which):
    """True if CUP gave up on PATH (only checked when the AST is empty)."""
    run = subprocess.run(["java", "-cp", CP, "chocopy.ChocoPy", "--pass=" + which, "--debug", path],
                         capture_output=True, text=True)
    return "Error recovery fails" in run.stdout + run.stderr


def top_level(d):
    return len(d["declarations"]) + len(d["statements"])

def one(args):
    src, rnd_seed, which = args
    rnd = random.Random(rnd_seed)
    text = open(src, newline="").read()
    lines = text.split("\n")
    code = [i for i, l in enumerate(lines) if l.strip() and not l.strip().startswith("#")]
    if len(code) < 3:
        return None
    i = rnd.choice(code)
    line = lines[i]
    indent = len(line) - len(line.lstrip(" \t"))
    pos = rnd.randint(indent, len(line))
    lines[i] = line[:pos] + " $ " + line[pos:]
    tmp = tempfile.mktemp(suffix=".py")
    with open(tmp, "w", newline="") as f:
        f.write("\n".join(lines))
    try:
        before = top_level(ast(src, which))
        after = ast(tmp, which)
        gave_up = top_level(after) == 0 and aborted(tmp, which)
    finally:
        os.unlink(tmp)
    return len(after["errors"]["errors"]), min(top_level(after), before), before, gave_up

def main():
    files = sorted(glob.glob(os.path.join(sys.argv[1], "good_*.py")))
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 150
    files = files[:limit]
    for which, label in (("r", "reference"), ("s", "ours")):
        with ThreadPoolExecutor(os.cpu_count() or 4) as pool:
            res = [r for r in pool.map(one, [(f, n, which) for n, f in enumerate(files)]) if r]
        exact = 100.0 * sum(1 for e, _, _, _ in res if e == 1) / len(res)
        avg = sum(e for e, _, _, _ in res) / len(res)
        kept = 100.0 * sum(k for _, k, _, _ in res) / sum(t for _, _, t, _ in res)
        aborted = sum(1 for _, _, _, a in res if a)
        print("%-10s programs=%d  exactly-one=%5.1f%%  avg errors=%.2f  kept=%5.1f%%  aborted=%d"
              % (label, len(res), exact, avg, kept, aborted))

if __name__ == "__main__":
    main()
