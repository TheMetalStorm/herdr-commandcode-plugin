#!/bin/sh
# Run all integration tests. No external deps (bats not required).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"
: > "$HERDR_CAPTURE"
fail=0
for t in "$ROOT"/tests/*.test.sh; do
  echo "== $(basename "$t") =="
  sh "$t" || fail=1
  echo
done
exit $fail
