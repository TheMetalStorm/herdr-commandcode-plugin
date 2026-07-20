#!/bin/sh
# Minimal POSIX test runner. Usage: sh tests/run.sh
# Each test file sources this and calls: t_title, t_ok, t_fail, t_assert_eq.
set -u

PASS=0
FAIL=0
CUR=""

t_title() { CUR="$1"; printf '  %s ... ' "$CUR"; }
t_ok()   { echo "ok"; PASS=$((PASS+1)); }
t_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
t_assert_eq() {
  # $1 expected $2 actual $3 msg
  if [ "$1" = "$2" ]; then t_ok; else t_fail "$3 (expected [$1] got [$2])"; fi
}

# Read the Nth captured invocation (1-based) from the capture file and return the
# value of a named flag, e.g. capture_flag 1 --state
# The stub writes one JSON array per line, e.g. ["pane","report-agent","pane-123",
# "--source","commandcode","--state","idle"]. We pull the element right after flag.
capture_flag() {
  n=$1; flag=$2
  sed -n "${n}p" "$HERDR_CAPTURE" \
    | node -e '
      let line=""; process.stdin.on("data",d=>line+=d).on("end",()=>{
        const a=JSON.parse(line); const i=a.indexOf(process.argv[1]);
        process.stdout.write(i>=0 && i+1<a.length ? String(a[i+1]) : "");
      });' -- "$flag"
}
# Positional arg of the Nth capture (0-based, after the command name at index 0).
capture_arg() {
  n=$1; idx=$2
  sed -n "${n}p" "$HERDR_CAPTURE" \
    | node -e '
      let line=""; process.stdin.on("data",d=>line+=d).on("end",()=>{
        const a=JSON.parse(line);
        process.stdout.write(a.length>process.argv[1] ? String(a[process.argv[1]]) : "");
      });' -- "$idx"
}
capture_count() { [ -f "$HERDR_CAPTURE" ] && wc -l < "$HERDR_CAPTURE" | tr -d ' ' || echo 0; }
clear_capture() { : > "$HERDR_CAPTURE"; }

summary() {
  echo "----------------------------------------"
  echo "PASS=$PASS FAIL=$FAIL"
  [ "$FAIL" -eq 0 ]
}
