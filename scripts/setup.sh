#!/bin/sh
# Seed the Command Code -> Herdr integration: install the status hook into
# Command Code's settings and seed the agent-detection override.
. "$(dirname "$0")/common.sh"
set -e
ensure_agent_detection
node "${HERDR_PLUGIN_ROOT}/cmd-hooks/install-hooks.mjs"
echo "Command Code <-> Herdr integration ready."
