#!/bin/sh
# Tests for scripts/common.sh ensure_agent_detection (copy-once behavior).
. "$(dirname "$0")/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON="$ROOT/scripts/common.sh"
SRC="$ROOT/config/agent-detection/cmd.toml"

echo "common.sh"

# ensure_agent_detection only acts inside herdr; drive it with env set.
setup_env() {
  FAKEHOME="$(mktemp -d)"
  export HOME="$FAKEHOME"
  export HERDR_ENV=1
  export HERDR_BIN_PATH="$ROOT/tests/fixtures/herdr-stub.sh"
  export HERDR_PLUGIN_ROOT="$ROOT"
  export HERDR_PLUGIN_CONFIG_DIR="$FAKEHOME/.herdr-config"
}

# 1. Copies the toml into the config dir when missing
setup_env
t_title "seeds agent-detection toml when missing"
. "$COMMON"
ensure_agent_detection
t_assert_eq "yes" "$([ -f "$HERDR_PLUGIN_CONFIG_DIR/agent-detection/cmd.toml" ] && echo yes || echo no)" "file copied"

# 2. Does not overwrite when identical (cmp -s short-circuits)
t_title "does not rewrite identical file"
. "$COMMON"
before_ts=$(stat -c %Y "$HERDR_PLUGIN_CONFIG_DIR/agent-detection/cmd.toml")
ensure_agent_detection
after_ts=$(stat -c %Y "$HERDR_PLUGIN_CONFIG_DIR/agent-detection/cmd.toml")
t_assert_eq "$before_ts" "$after_ts" "mtime unchanged (not rewritten)"

# 3. Overwrites when source differs
t_title "overwrites when source changed"
printf '# changed\n' > "$SRC.tmp"
cp "$SRC" "$SRC.bak"; cp "$SRC.tmp" "$SRC"
. "$COMMON"
ensure_agent_detection
got=$(head -1 "$HERDR_PLUGIN_CONFIG_DIR/agent-detection/cmd.toml")
cp "$SRC.bak" "$SRC"; rm -f "$SRC.tmp" "$SRC.bak"
t_assert_eq "# changed" "$got" "updated to new content"

# 4. No-op outside herdr
unset HERDR_ENV
FAKEHOME2="$(mktemp -d)"; export HOME="$FAKEHOME2"
export HERDR_PLUGIN_CONFIG_DIR="$FAKEHOME2/.herdr-config"
t_title "no-op outside herdr"
. "$COMMON"
ensure_agent_detection
t_assert_eq "no" "$([ -f "$HERDR_PLUGIN_CONFIG_DIR/agent-detection/cmd.toml" ] && echo yes || echo no)" "nothing written"

rm -rf "$FAKEHOME" "$FAKEHOME2"
summary
