#!/bin/sh
# Tests for scripts/launch.sh (mode resolution + resume-named extraction).
# We don't exec cmd; instead we source the logic up to the exec by intercepting
# via a wrapper that stops before `exec cmd`. Simpler: copy the arg-resolution
# branch by running launch.sh with cmd replaced by the stub and HERDR_ENV unset
# so it still resolves args and execs "cmd" -> we capture the argv.
. "$(dirname "$0")/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCH="$ROOT/scripts/launch.sh"
STUB="$ROOT/tests/fixtures/herdr-stub.sh"
HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"
export HERDR_CAPTURE
export HERDR_BIN_PATH="$STUB"
export HERDR_PANE_ID="pane-1"
unset HERDR_ENV   # launch.sh doesn't require herdr env; it just runs cmd

# Make `cmd` resolve to our stub so `exec cmd ...` is captured instead of running
CMD_DIR="$ROOT/tests/fixtures/bin"
mkdir -p "$CMD_DIR"
cat > "$CMD_DIR/cmd" <<'EOF'
#!/bin/sh
# stub cmd: record argv
OUT="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"
printf '%s\n' "$(printf '%s\0' "$@" | sed 's/"/\\"/g; s/\x00/","/g; s/^/["/; s/$/"]/')" >> "$OUT"
EOF
chmod +x "$CMD_DIR/cmd"
export PATH="$CMD_DIR:$PATH"

echo "launch.sh"

# 1. task mode -> cmd invoked with no args (stub captures argv)
clear_capture
t_title "task mode -> cmd with no args"
sh "$LAUNCH" task
t_assert_eq "1" "$(capture_count)" "cmd invoked once"
t_assert_eq "" "$(capture_arg 1 0)" "no args passed to cmd"

# 2. resume-last -> -c
clear_capture
t_title "resume-last passes -c"
sh "$LAUNCH" resume-last
t_assert_eq "1" "$(capture_count)" "cmd invoked once"
t_assert_eq "-c" "$(capture_arg 1 0)" "first arg is -c"

# 3. resume-named with explicit arg
clear_capture
t_title "resume-named with arg -> --resume name"
sh "$LAUNCH" resume-named my-session
t_assert_eq "--resume" "$(capture_arg 1 0)" "has --resume"
t_assert_eq "my-session" "$(capture_arg 1 1)" "session name passed"

# 4. resume-named without arg but with context JSON
clear_capture
t_title "resume-named from context json"
export HERDR_PLUGIN_CONTEXT_JSON='{"session_name":"ctx-session"}'
sh "$LAUNCH" resume-named
t_assert_eq "ctx-session" "$(capture_arg 1 1)" "session name from context"
unset HERDR_PLUGIN_CONTEXT_JSON

# 5. resume-named with no name -> error exit
clear_capture
t_title "resume-named without name exits 1"
sh "$LAUNCH" resume-named >/dev/null 2>&1
t_assert_eq "1" "$?" "exit code 1"

summary
