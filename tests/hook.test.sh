#!/bin/sh
# Tests for cmd-hooks/herdr-status.sh
. "$(dirname "$0")/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/cmd-hooks/herdr-status.sh"
STUB="$ROOT/tests/fixtures/herdr-stub.sh"
HERDR_CAPTURE="${HERDR_CAPTURE:-/tmp/herdr-capture.jsonl}"
export HERDR_CAPTURE
export HERDR_BIN_PATH="$STUB"
export HERDR_PANE_ID="pane-123"
# SessionStart starts a watcher in production. Keep test watchers single-scan
# so they cannot outlive this test process.
export HERDR_PERMISSION_MAX_SCANS=1

# Run the hook with a payload; HERDR_ENV must be set by caller.
run_hook() { echo "$1" | sh "$HOOK"; }

echo "herdr-status.sh"

# 1. No-op when NOT inside herdr (HERDR_ENV unset)
clear_capture
t_title "no-op outside herdr"
unset HERDR_ENV
run_hook '{"hook_event_name":"SessionStart","session_id":"s1"}'
t_assert_eq "0" "$(capture_count)" "should not call herdr"

# 2. SessionStart -> idle + label + session with --session-start-source
clear_capture
t_title "SessionStart reports idle + label + session"
export HERDR_ENV=1
run_hook '{"hook_event_name":"SessionStart","session_id":"sess-abc"}'
t_assert_eq "3" "$(capture_count)" "expected 3 calls (report-agent + report-metadata + report-agent-session)"
t_assert_eq "idle" "$(capture_flag 1 --state)" "SessionStart state is idle"
t_assert_eq "cmd" "$(capture_flag 2 --display-agent)" "display-agent label set"
t_assert_eq "sess-abc" "$(capture_flag 3 --agent-session-id)" "session id reported"
t_assert_eq "new" "$(capture_flag 3 --session-start-source)" "session-start-source is new"

# 3. PreToolUse with non-blocking tool -> working
clear_capture
t_title "PreToolUse (Read) reports working"
run_hook '{"hook_event_name":"PreToolUse","tool_name":"Read","session_id":"s1"}'
t_assert_eq "1" "$(capture_count)" "one call"
t_assert_eq "working" "$(capture_flag 1 --state)" "non-blocking tool is working"

# 4. PreToolUse with blocking tool (AskUserQuestion) -> blocked
clear_capture
t_title "PreToolUse (AskUserQuestion) reports blocked"
run_hook '{"hook_event_name":"PreToolUse","tool_name":"AskUserQuestion","tool_input":{"choices":["a","b"]},"session_id":"s1"}'
t_assert_eq "blocked" "$(capture_flag 1 --state)" "blocking tool is blocked"

# 5. PostToolUse -> working
clear_capture
t_title "PostToolUse reports working"
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Read","session_id":"s1"}'
t_assert_eq "working" "$(capture_flag 1 --state)" "PostToolUse state"

# 6. Stop -> idle
clear_capture
t_title "Stop reports idle"
run_hook '{"hook_event_name":"Stop","session_id":"s1"}'
t_assert_eq "idle" "$(capture_flag 1 --state)" "Stop state"

# 7. JSON robustness: tool_input is a nested object with commas/braces
clear_capture
t_title "parses event with nested tool_input"
run_hook '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo a, b {c}"},"session_id":"s9"}'
t_assert_eq "working" "$(capture_flag 1 --state)" "non-blocking tool still maps correctly"

# 8. Comma inside session_id value must be preserved verbatim
clear_capture
t_title "comma inside session_id value"
run_hook '{"hook_event_name":"SessionStart","session_id":"a,b,c"}'
t_assert_eq "a,b,c" "$(capture_flag 3 --agent-session-id)" "comma preserved"

# 9. Exact visible shell-command permission prompt -> blocked
clear_capture
t_title "exact shell permission prompt reports blocked"
export HERDR_PANE_CONTENT='Execute Shell Command
Command Code needs to execute cd /workspace && flutter analyze'
sh "$HOOK" --watch-shell-permission
t_assert_eq "1" "$(capture_count)" "one blocked report"
t_assert_eq "blocked" "$(capture_flag 1 --state)" "exact prompt is blocked"
t_assert_eq "commandcode" "$(capture_flag 1 --source)" "uses Command Code authority"
t_assert_eq "cmd" "$(capture_flag 1 --agent)" "uses cmd agent label"
permission_seq=$(capture_flag 1 --seq)
t_assert_eq "yes" "$([ -n "$permission_seq" ] && [ "$permission_seq" -eq "$permission_seq" ] 2>/dev/null && echo yes || echo no)" "blocked report has numeric seq"

# 10. Near miss must not match only one prompt line.
clear_capture
t_title "near-miss shell permission prompt is ignored"
export HERDR_PANE_CONTENT='Execute Shell Command
Command Code will execute'
sh "$HOOK" --watch-shell-permission
t_assert_eq "0" "$(capture_count)" "near miss does not report blocked"

# 11. A matching screen reports once until the prompt clears, then can report again.
clear_capture
t_title "shell permission watcher debounces and resets"
PERMISSION_TMP=$(mktemp -d)
export HERDR_PANE_CONTENT_SEQUENCE_FILE="$PERMISSION_TMP/screens"
export HERDR_PANE_READ_COUNT_FILE="$PERMISSION_TMP/read-count"
unset HERDR_PANE_CONTENT
printf '%s\n---HERDR-PANE-READ---\n%s\n---HERDR-PANE-READ---\n\n---HERDR-PANE-READ---\n%s' \
  'Execute Shell Command
Command Code needs to execute' \
  'Execute Shell Command
Command Code needs to execute' \
  'Execute Shell Command
Command Code needs to execute' > "$HERDR_PANE_CONTENT_SEQUENCE_FILE"
export HERDR_PERMISSION_MAX_SCANS=4
sh "$HOOK" --watch-shell-permission
t_assert_eq "2" "$(capture_count)" "one report before and after the prompt clears"
t_assert_eq "blocked" "$(capture_flag 1 --state)" "first matching screen is blocked"
t_assert_eq "blocked" "$(capture_flag 2 --state)" "matching screen after clear is blocked"
rm -rf "$PERMISSION_TMP"
unset HERDR_PANE_CONTENT_SEQUENCE_FILE HERDR_PANE_READ_COUNT_FILE
export HERDR_PERMISSION_MAX_SCANS=1

# 12. --seq is present and monotonically increasing per pane (authority counter)
TMP_SEQ="$(mktemp -d)"
export TMPDIR="$TMP_SEQ"
export HERDR_PANE_ID="seq-pane-test"
clear_capture
t_title "seq present + increasing"
run_hook '{"hook_event_name":"PreToolUse","tool_name":"Read","session_id":"s1"}'
s1=$(capture_flag 1 --seq)
run_hook '{"hook_event_name":"PostToolUse","tool_name":"Read","session_id":"s1"}'
s2=$(capture_flag 2 --seq)
t_assert_eq "yes" "$([ -n "$s1" ] && [ "$s1" -eq "$s1" ] 2>/dev/null && echo yes || echo no)" "seq is numeric"
t_assert_eq "yes" "$([ "$s2" -gt "$s1" ] 2>/dev/null && echo yes || echo no)" "seq increases across calls"
rm -rf "$TMP_SEQ"

summary
