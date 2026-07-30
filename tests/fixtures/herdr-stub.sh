#!/bin/sh
# Capture stub standing in for the real `herdr` binary.
# Every invocation is appended as one JSON array line to $HERDR_CAPTURE
# (default /tmp/herdr-capture.jsonl), using node to guarantee valid JSON.
# Used by the test suite to assert what the hook / scripts would have told herdr.
export HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"

# The permission watcher reads several pane sources. Return configurable content
# without recording a lifecycle call, so hook assertions remain focused on what
# was reported to Herdr. Source-specific variables override generic ones:
# HERDR_PANE_CONTENT_VISIBLE, _DETECTION, _RECENT, or _RECENT_UNWRAPPED.
# Source-specific sequence/count variables follow the same naming pattern.
if [ "$1" = "pane" ] && [ "$2" = "read" ]; then
  pane_source="recent"
  shift 2
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--source" ] && [ "$#" -gt 1 ]; then
      pane_source=$2
      break
    fi
    shift
  done

  case "$pane_source" in
    visible)
      pane_content="${HERDR_PANE_CONTENT_VISIBLE-${HERDR_PANE_CONTENT:-}}"
      sequence_file="${HERDR_PANE_CONTENT_VISIBLE_SEQUENCE_FILE:-${HERDR_PANE_CONTENT_SEQUENCE_FILE:-}}"
      count_file="${HERDR_PANE_READ_COUNT_VISIBLE_FILE:-${HERDR_PANE_READ_COUNT_FILE:-}}"
      ;;
    detection)
      pane_content="${HERDR_PANE_CONTENT_DETECTION-${HERDR_PANE_CONTENT:-}}"
      sequence_file="${HERDR_PANE_CONTENT_DETECTION_SEQUENCE_FILE:-${HERDR_PANE_CONTENT_SEQUENCE_FILE:-}}"
      count_file="${HERDR_PANE_READ_COUNT_DETECTION_FILE:-${HERDR_PANE_READ_COUNT_FILE:-}}"
      ;;
    recent-unwrapped)
      pane_content="${HERDR_PANE_CONTENT_RECENT_UNWRAPPED-${HERDR_PANE_CONTENT:-}}"
      sequence_file="${HERDR_PANE_CONTENT_RECENT_UNWRAPPED_SEQUENCE_FILE:-${HERDR_PANE_CONTENT_SEQUENCE_FILE:-}}"
      count_file="${HERDR_PANE_READ_COUNT_RECENT_UNWRAPPED_FILE:-${HERDR_PANE_READ_COUNT_FILE:-}}"
      ;;
    *)
      pane_content="${HERDR_PANE_CONTENT_RECENT-${HERDR_PANE_CONTENT:-}}"
      sequence_file="${HERDR_PANE_CONTENT_RECENT_SEQUENCE_FILE:-${HERDR_PANE_CONTENT_SEQUENCE_FILE:-}}"
      count_file="${HERDR_PANE_READ_COUNT_RECENT_FILE:-${HERDR_PANE_READ_COUNT_FILE:-}}"
      ;;
  esac

  if [ -n "$sequence_file" ]; then
    HERDR_STUB_SEQUENCE_FILE="$sequence_file" HERDR_STUB_COUNT_FILE="$count_file" node -e '
      const fs=require("fs");
      const sequence=fs.readFileSync(process.env.HERDR_STUB_SEQUENCE_FILE,"utf8")
        .split("\n---HERDR-PANE-READ---\n");
      const countFile=process.env.HERDR_STUB_COUNT_FILE;
      const count=countFile && fs.existsSync(countFile) ? Number(fs.readFileSync(countFile,"utf8")) || 0 : 0;
      if (countFile) fs.writeFileSync(countFile,String(count+1));
      process.stdout.write(sequence[Math.min(count, sequence.length-1)] || "");
    '
  else
    printf '%s' "$pane_content"
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
