# herdr-integration
- For herdr plugin integration: agent status should transition to done/idle without requiring the agent process (cmd) to exit/close. Match opencode's lifecycle model where the agent stays alive while status reflects completion. Confidence: 0.70
- When using `herdr pane send-text`, press Enter afterward (via `\n` or separate send-text of `\n`) to submit/execute the command; otherwise the text is just typed without executing. Confidence: 0.65
- On force-quit (user manually kills the pane/agent process), the herdr status should still transition to idle rather than remaining stuck. Confidence: 0.70
- Herdr agent state definitions: `blocked` = needs input/approval/decision, `working` = actively running, `done` = finished but unseen by user, `idle` = finished/waiting and seen, `unknown` = cannot classify. Confidence: 0.75
- Permission prompts (e.g., "Do you want to make this edit?") should also trigger `blocked` state in herdr, not just AskUserQuestion/Question tools. The `is_blocking_tool` check needs to cover all user-confirmation dialogs including `edit_file` and `write_file`. Confidence: 0.75
- Match OpenCode's plugin lifecycle: SessionStart should report `idle` (not `working`). OpenCode shows a green checkmark on start because it starts idle and only transitions to working when actually processing. Confidence: 0.70
- Use HTTPS (not SSH) for git remote URLs when interacting with GitHub. Standard HTTP authentication is preferred over SSH key-based auth. Confidence: 0.65
