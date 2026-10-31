#!/usr/bin/env python3
"""Print a ChocoPy AST (the JSON written by --out) as an indented tree.

One line per node: kind, location [line, col, line, col] and its plain
attributes (name, operator, value, ...).

Usage:  python3 tools/ast_tree.py ast.json
        java ... chocopy.ChocoPy --pass=s file.py | python3 tools/ast_tree.py
"""
import json
import sys


def show(node, depth=0, label=""):
    pad = "  " * depth
    if isinstance(node, list):
        for item in node:
            show(item, depth, label)
        return
    if not isinstance(node, dict):
        return
    attrs = {k: v for k, v in node.items()
             if not isinstance(v, (dict, list)) and k not in ("kind", "location")}
    extra = "  " + " ".join("%s=%s" % (k, json.dumps(v)) for k, v in attrs.items()) if attrs else ""
    prefix = (label + ": ") if label else ""
    print("%s%s%s %s%s" % (pad, prefix, node.get("kind", "?"), node.get("location"), extra))
    for key, value in node.items():
        if key == "location" or not isinstance(value, (dict, list)):
            continue
        if isinstance(value, list) and not value:
            print("%s  %s: []" % (pad, key))
        else:
            show(value, depth + 1, key)


def main():
    text = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    text = text[text.index("{"):]          # skip the driver's "Reading <file>" line
    show(json.loads(text))


if __name__ == "__main__":
    main()
