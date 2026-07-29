#!/bin/sh
# Capture stub standing in for the real `herdr` binary.
# Every invocation is appended as one JSON array line to $HERDR_CAPTURE
# (default /tmp/herdr-capture.jsonl), using node to guarantee valid JSON.
# Used by the test suite to assert what the hook / scripts would have told herdr.
export HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"

# The permission watcher reads visible pane content. Return configurable content
# without recording a lifecycle call, so hook assertions remain focused on what
# was reported to Herdr. A sequence file supplies one screen per read.
if [ "$1" = "pane" ] && [ "$2" = "read" ]; then
  if [ -n "${HERDR_PANE_CONTENT_SEQUENCE_FILE:-}" ]; then
    node -e '
      const fs=require("fs");
      const sequence=fs.readFileSync(process.env.HERDR_PANE_CONTENT_SEQUENCE_FILE,"utf8")
        .split("\n---HERDR-PANE-READ---\n");
      const countFile=process.env.HERDR_PANE_READ_COUNT_FILE;
      const count=fs.existsSync(countFile) ? Number(fs.readFileSync(countFile,"utf8")) || 0 : 0;
      fs.writeFileSync(countFile,String(count+1));
      process.stdout.write(sequence[Math.min(count, sequence.length-1)] || "");
    '
  else
    printf '%s' "${HERDR_PANE_CONTENT:-}"
  fi
  exit 0
fi

node -e '
const fs=require("fs");
const args=process.argv.slice(1);
fs.appendFileSync(process.env.HERDR_CAPTURE, JSON.stringify(args)+"\n");
process.exit(0);
' "$@" < /dev/null
exit 0
