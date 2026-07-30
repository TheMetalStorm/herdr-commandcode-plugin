# General Preferences
- Before entering plan mode, the user should be explicitly asked/prompted for confirmation rather than having the agent transition automatically. Confidence: 0.75
- When a plan is written in plan mode, the agent must explicitly ask the user for approval before exiting plan mode; it should never declare a plan "approved" without the user's confirmation. Confidence: 0.9
- The agent should use AskUserQuestion (or equivalent) to request plan approval from the user rather than silently proceeding to exit_plan_mode. Confidence: 0.85
- When the user explicitly instructs the agent to enter plan mode (e.g., "switch to plan mode"), the agent should comply immediately — the user's direct instruction is the authorization, and no additional confirmation prompt is needed. Confidence: 0.85
- When the user explicitly requests a minimal or trivial plan (e.g., "pointless plan with 1 line"), the agent should honor that constraint and not over-elaborate or expand the plan. Confidence: 0.80
