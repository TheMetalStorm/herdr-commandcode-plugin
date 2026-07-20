#!/bin/sh
# Capture stub standing in for the real `herdr` binary.
# Every invocation is appended as one JSON array line to $HERDR_CAPTURE
# (default /tmp/herdr-capture.jsonl), using node to guarantee valid JSON.
# Used by the test suite to assert what the hook / scripts would have told herdr.
export HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"
node -e '
const fs=require("fs");
const args=process.argv.slice(1);
fs.appendFileSync(process.env.HERDR_CAPTURE, JSON.stringify(args)+"\n");
process.exit(0);
' "$@" < /dev/null
exit 0
