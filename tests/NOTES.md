# Test Notes / Known Deviations

## Force-quit gap (the question that prompted testing)
Command Code has **no `Exit` hook event**. When the user force-quits the pane
(kills the `cmd` process), neither `Stop` nor any exit hook fires, so
`herdr-status.sh` never reports a final state. The sidebar relies entirely on:
  1. the persisted agent claim (`Stop` -> `idle`, keeping authority), and
  2. Herdr's own process detection noticing the `cmd` process died.

There is **no automated test** proving Herdr flips the pane to `idle`/`unknown`
on force-quit, because that path is owned by Herdr, not by this plugin. The
expected behavior (per taste + README): on force-quit the agent state should
transition to `idle`, not stay stuck on `blocked`/`working`.

To manually verify: open a `commandcode.integration.task` pane, let it reach
`working`/`blocked`, then kill the pane process from another terminal and
observe Herdr's sidebar. If it stays stuck, the plugin needs an external
watchdog (e.g. a wrapper that traps SIGTERM/SIGKILL is impossible for SIGKILL;
a sidecar polling the process is the realistic option).

## State semantics deviation
Herdr's state vocabulary (confirmed via schema):
  - `blocked` = agent needs input/approval/decision
  - `working` = actively running
  - `done`    = finished, unseen by user
  - `idle`    = finished/waiting, seen
  - `unknown` = cannot classify

The hook maps `SessionStart -> idle` and `Stop -> idle`. It therefore:
  - never reports `done` (finished-but-unseen), and
  - reports `idle` at SessionStart, which mislabels a just-started session as
    already "seen/finished" until the first tool call flips it to `blocked`.

The README claims SessionStart -> `working` and Stop -> `idle`/`done`; the code
does not match the README. The README text in herdr-status.sh header also still
says "SessionStart -> working" while the code does `idle`. This mismatch should
be reconciled (either fix the code to use `working`/`done`, or fix the docs).

## How Herdr renders the 5 states (verified from binary + live observation)
Observed rendering (desktop, herdr 0.7.4):

Space/tab strip:
  - working  -> orange/yellow FILLED dot
  - done     -> green/yellow UNFILLED dot
  - blocked  -> filled dot (binary glyph `◉`); fleeting during tool calls
  - idle     -> (minimal/dot)
  - unknown  -> RED marker  <-- this is the "red dot" reported earlier

Agent panel:
  - working  -> orange/yellow loading/spinner symbol
  - done     -> checkmark
  - blocked  -> loading/spinner-like (distinct from working only by timing)
  - idle     -> minimal
  - unknown  -> red marker

Key finding: surfaces that cannot infer the agent from the process fall back to
`unknown` (red). The hook MUST call `report-metadata --display-agent cmd` so both
the agent panel AND the space/tab label the pane as the `cmd` agent. This was
MISSING before and caused the red `unknown` dot on the space surface. Fixed:
`label()` now runs on SessionStart. Confirmed live: after setting display-agent,
w7:p1 stopped showing unknown and rendered blocked/idle correctly.

Note: `done` is only reachable via the `AgentStatus` field, NOT `report-agent`
(which accepts idle|working|blocked|unknown). The hook sends `idle` on Stop, so
it never produces the checkmark `done` state.

## `resume-last` flag
`launch.sh` passes `-c` for resume-last. Confirmed against `cmd --help`
(`cmd` v0.52.1): `-c, --continue` = "Continue the last conversation". Correct.
The only failure mode is when run without a TTY (interactive mode requires a
terminal), which is expected inside a real Herdr pane PTY, not a test pipe.
