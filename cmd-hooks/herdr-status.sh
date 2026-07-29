#!/bin/sh
# Command Code -> Herdr status hook.
#
# Installed as a Command Code hook (SessionStart / PreToolUse / PostToolUse /
# Stop). It runs INSIDE the live cmd process so Command Code does NOT need to
# exit for herdr to learn its status. Mirrors the OpenCode herdr-agent-state.js
# plugin: SessionStart claims the agent and reports `idle`, PreToolUse
# reports `working` (only `blocked` for interactive blocking tools),
# PostToolUse reports `working`, Stop reports `idle`.
#
# The agent claim is kept alive for the pane's lifetime so herdr keeps showing
# the agent even when the matched cmd process ends between turns. (Command Code
# has no `Exit` hook event, so abnormal-exit handling relies on the persistent
# claim + herdr's own process detection.)
#
# Command Code invokes this with a JSON hook payload on stdin:
#   { "hook_event_name": "...", "session_id": "...", "cwd": "...",
#     "tool_name": "...", "tool_input": {...} }
#
# It reports to herdr through $HERDR_BIN_PATH (the running herdr binary). When
# cmd is not running inside herdr (no HERDR_ENV), the hook is a no-op.

HERDR="${HERDR_BIN_PATH:-herdr}"

# Only act when cmd is running inside a managed herdr pane.
[ "${HERDR_ENV:-}" = "1" ] || exit 0
PANE_ID="${HERDR_PANE_ID:-}"
[ -n "$PANE_ID" ] || exit 0

# Monotonic authority counter. Uses nanosecond-precision timestamp as seed
# so each report carries a unique, always-increasing seq, matching OpenCode's
# `reportSeq = Date.now() * 1000` + increment pattern.
SEQ_FILE="${TMPDIR:-/tmp}/herdr-cmd-seq-${PANE_ID}"
next_seq() {
  lock_dir="${SEQ_FILE}.lock"
  attempts=0
  while ! mkdir "$lock_dir" 2>/dev/null; do
    attempts=$((attempts + 1))
    [ "$attempts" -lt 100 ] || return 1
    sleep 0.01
  done

  if [ -f "$SEQ_FILE" ]; then
    seq=$(cat "$SEQ_FILE" 2>/dev/null | tr -dc '0-9')
  else
    seq=$(node -e 'process.stdout.write(String(Date.now()*1000))')
  fi
  seq=$(( ${seq:-0} + 1 ))
  printf '%s' "$seq" > "$SEQ_FILE"
  rmdir "$lock_dir" 2>/dev/null
  printf '%s' "$seq"
}

report() {
  "$HERDR" pane report-agent "$PANE_ID" \
    --source commandcode --agent cmd --state "$1" --seq "$(next_seq)" >/dev/null 2>&1
}

# Claim the agent label on BOTH surfaces (agent panel + space/tab). Without
# this, surfaces that can't infer the agent from the process fall back to
# `unknown` (red dot). Mirrors how OpenCode's herdr plugin establishes the
# agent identity once per session.
label() {
  "$HERDR" pane report-metadata "$PANE_ID" \
    --source commandcode --agent cmd --display-agent cmd >/dev/null 2>&1
}

# Command Code renders this prompt after a shell command requests approval.
# It is read from the live screen, rather than history, so a resolved prompt
# cannot keep the pane blocked on a later turn.
SHELL_PERMISSION_SIGNAL='Execute Shell Command
Command Code needs to execute'

has_shell_permission_prompt() {
  pane_content=$("$HERDR" pane read "$PANE_ID" --source visible 2>/dev/null) || return 2
  case "$pane_content" in
    *"$SHELL_PERMISSION_SIGNAL"*) return 0 ;;
    *) return 1 ;;
  esac
}

watch_shell_permission() {
  seen=0
  read_failures=0
  scans=0
  max_scans="${HERDR_PERMISSION_MAX_SCANS:-}"

  while :; do
    if has_shell_permission_prompt; then
      read_failures=0
      if [ "$seen" -eq 0 ]; then
        report blocked
        seen=1
      fi
    else
      read_result=$?
      if [ "$read_result" -eq 2 ]; then
        read_failures=$((read_failures + 1))
        [ "$read_failures" -lt "${HERDR_PERMISSION_MAX_READ_FAILURES:-5}" ] || break
      else
        read_failures=0
        seen=0
      fi
    fi

    scans=$((scans + 1))
    [ -z "$max_scans" ] || [ "$scans" -lt "$max_scans" ] || break
    sleep "${HERDR_PERMISSION_POLL_INTERVAL:-1}"
  done
}

start_shell_permission_watcher() {
  watcher_dir="${TMPDIR:-/tmp}/herdr-cmd-shell-permission-watcher-${PANE_ID}"
  mkdir "$watcher_dir" 2>/dev/null || return 0
  (
    trap 'rmdir "$watcher_dir" 2>/dev/null' 0 HUP INT TERM
    watch_shell_permission
  ) &
}

# Internal test/worker modes must not consume a Command Code JSON payload.
case "${1:-}" in
  --watch-shell-permission)
    watch_shell_permission
    exit 0
    ;;
esac

# Read the hook payload (one JSON object) from stdin.
PAYLOAD=$(cat)

# Robust extraction: parse JSON instead of pattern-matching.
EVENT=$(printf '%s' "$PAYLOAD"   | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.hook_event_name||"")}catch{}})')
SESSION=$(printf '%s' "$PAYLOAD" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.session_id||"")}catch{}})')
TOOL=$(printf '%s' "$PAYLOAD"    | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.tool_name||"")}catch{}})')

# Blocking tools are the ones that pause cmd waiting for user input/decision
# (arrow-key choices, permission prompts). Following OpenCode's model, only
# these tools surface as `blocked`; everything else is `working`.
is_blocking_tool() {
  case "$TOOL" in
    AskUserQuestion|Question|ask_user_question|question|edit_file|write_file) return 0 ;;
    *) return 1 ;;
  esac
}

case "$EVENT" in
  SessionStart)
    report idle
    label
    if [ -n "$SESSION" ]; then
      "$HERDR" pane report-agent-session "$PANE_ID" \
        --source commandcode --agent cmd \
        --agent-session-id "$SESSION" \
        --session-start-source new \
        --seq "$(next_seq)" >/dev/null 2>&1
    fi
    start_shell_permission_watcher
    ;;
  PreToolUse)
    if is_blocking_tool; then
      report blocked
    else
      report working
    fi
    ;;
  PostToolUse)
    report working
    ;;
  Stop)
    report idle
    ;;
esac

exit 0
