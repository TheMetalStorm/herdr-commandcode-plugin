# Command Code — Herdr Integration

Makes [Command Code](https://commandcode.ai) (`cmd`) a first-class agent inside
[Herdr](https://herdr.dev), the terminal multiplexer for coding agents.

- **Accurate lifecycle state** — while `cmd` runs, Herdr's sidebar shows it as
  `working`; during a tool call it shows `blocked`; when it finishes a turn it
  flips to `idle`/`done`; on abnormal exit it shows `unknown`. `cmd` does **not**
  need to exit for the status to update. (Herdr's `report-agent` only accepts
  `idle|working|blocked|unknown`, so those are the states used.)
- **Session restore** — reports the Command Code session id to Herdr so a pane can
  be resumed after a Herdr restart with `cmd --resume <id>`.
- **Sidebar detection** — Herdr recognizes the `cmd`/`command-code` process as the
  `cmd` agent (agent-detection override seeded on setup).
- **Launch panes** — open Command Code in a real terminal pane: new task, resume
  last session, or resume a named session.
- **Notifications** — a `notify` action sends a Herdr toast.

## How status reporting works (important)

This integration follows the same model as Herdr's OpenCode/Codex integrations:
the **status is reported from inside the live `cmd` process**, not by the launcher.

Command Code has a hooks system (Claude Code-compatible: `PreToolUse`,
`PostToolUse`, `Stop`, `SessionStart`, `Exit`). This plugin installs a hook
(`cmd-hooks/herdr-status.sh`) into `~/.commandcode/settings.json` that:

- on `SessionStart` → reports `working` + session id to Herdr
- on `PreToolUse` → reports `blocked` (live tool activity in the sidebar)
- on `PostToolUse` → reports `working` (back to general working)
- on `Stop` (a turn finished) → reports `idle` and keeps the lifecycle claim

Herdr's `report-agent` only accepts `idle|working|blocked|unknown`, so the hook
maps to those. Command Code has no `Exit` hook event, so abnormal-exit handling
relies on the persistent agent claim plus Herdr's own process detection. Because
the report comes from the running agent, the sidebar stays accurate the whole
time `cmd` is open — no need to close `cmd` to see `done`.

## Requirements

- Herdr >= 0.7.0 (`herdr --version`)
- `cmd` on your `PATH` (install via `npm i -g command-code`)

## Install

```bash
herdr plugin link /path/to/commandcode-herdr-integration
# Wire the Command Code hook + agent detection into your Command Code config:
herdr plugin action invoke commandcode.integration.setup
```

From GitHub (after publishing with the `herdr-plugin` topic):

```bash
herdr plugin install <you>/commandcode-herdr
herdr plugin action invoke commandcode.integration.setup
```

The `setup` action writes `~/.commandcode/settings.json` (hook) and fingerprints
the command in `~/.commandcode/trusted-hooks.json`, and seeds the agent-detection
override. To remove it: `node cmd-hooks/install-hooks.mjs --uninstall`.

## Use

Open a Command Code session as a Herdr pane:

```bash
herdr plugin pane open --plugin commandcode.integration --entrypoint task
herdr plugin pane open --plugin commandcode.integration --entrypoint resume-last
herdr plugin pane open --plugin commandcode.integration --entrypoint resume-named
```

Send a notification:

```bash
herdr plugin action invoke commandcode.integration.notify "Build done" "api workspace"
```

Bind a key in your Herdr config:

```toml
[[keys.command]]
key = "prefix+c"
type = "plugin_pane"
command = "commandcode.integration.task"
description = "Command Code: new task"
```

## Files

- `herdr-plugin.toml` — manifest: launch panes + `setup`/`notify` actions.
- `cmd-hooks/herdr-status.sh` — Command Code hook (SessionStart→working,
  PreToolUse→tool_use, PostToolUse→working, Stop→idle, Exit→error) reporting to
  the Herdr socket. Runs inside the live `cmd` process.
- `cmd-hooks/install-hooks.mjs` — installs/removes the hook in Command Code's
  `settings.json` and `trusted-hooks.json`.
- `scripts/launch.sh` — pane entrypoint; runs `cmd` (the hook owns state reporting).
- `scripts/common.sh` — shared helpers (agent-detection seeding).
- `scripts/notify.sh` — sends a Herdr notification (action).
- `config/agent-detection/cmd.toml` — agent-detection override for the `cmd` process.

## Notes / limitations

- Launching uses plugin **panes** (real PTYs) rather than actions, because Herdr
  runs actions as detached non-TTY subprocesses and `cmd` needs a TTY.
- Windows is supported via Git Bash (scripts are POSIX `sh`); the hook uses
  `HERDR_BIN_PATH` so it is portable across Unix sockets / Windows named pipes.
- Verify the exact agent-detection schema on your Herdr version with
  `herdr api schema --json` and adjust `config/agent-detection/cmd.toml` if field
  names differ.
