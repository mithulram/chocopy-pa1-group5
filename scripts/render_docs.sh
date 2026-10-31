#!/usr/bin/env bash
# Re-render docs/*.pdf from the HTML sources in docs/src/ with headless
# Chrome (or Chromium). Run this after editing any document.
#
# Usage (from the repository root):  bash scripts/render_docs.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "$(command -v google-chrome || true)" "$(command -v chromium || true)" \
           "$(command -v chromium-browser || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then CHROME="$c"; break; fi
  done
fi
[ -n "$CHROME" ] || { echo "Chrome/Chromium not found - set CHROME=/path/to/chrome"; exit 1; }

PROFILE="$(mktemp -d)"
trap 'rm -rf "$PROFILE"' EXIT
for src in "$ROOT"/docs/src/*.html; do
  out="$ROOT/docs/$(basename "${src%.html}").pdf"
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --user-data-dir="$PROFILE" \
    --print-to-pdf="$out" "file://$src" 2>/dev/null
  echo "rendered $(basename "$out")"
done
