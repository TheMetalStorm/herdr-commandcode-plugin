#!/bin/sh
# Launch Command Code (cmd) inside a herdr plugin PANE.
#
# Herdr runs plugin pane entrypoints as the pane's own PTY process, so `cmd`
# gets a real TTY and its interactive TUI works. (Plugin actions/CLI have no TTY
# and cannot launch interactive agents, which is why these are panes, not actions.)
#
# Lifecycle state is reported by the Command Code hook (cmd-hooks/herdr-status.sh),
# which runs INSIDE the live cmd process on SessionStart (working) and Stop (idle).
# That hook is installed via cmd-hooks/install-hooks.mjs. This launcher just seeds
# agent detection and runs cmd.
#
# Usage: launch.sh <task|resume-last|resume-named> [session-name]
. "$(dirname "$0")/common.sh"

mode="${1:-task}"
name="${2:-}"

ensure_agent_detection

case "$mode" in
  task)
    CMD_ARGS=""
    ;;
  resume-last)
    CMD_ARGS="-c"
    ;;
  resume-named)
    if [ -z "$name" ]; then
      name=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" 2>/dev/null \
        | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.session_name||"")}catch{}})' 2>/dev/null)
    fi
    if [ -z "$name" ]; then
      echo "resume-named requires a session name (arg or context)" >&2
      exit 1
    fi
    CMD_ARGS="--resume $name"
    ;;
  *)
    echo "unknown launch mode: $mode" >&2
    exit 1
    ;;
esac

# Run cmd as the pane's PTY process. The installed Command Code hook reports
# working/idle to herdr from inside cmd; this script just hands over the terminal.
# shellcheck disable=SC2086
exec cmd $CMD_ARGS
