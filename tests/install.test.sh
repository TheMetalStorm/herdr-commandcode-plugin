#!/bin/sh
# Tests for cmd-hooks/install-hooks.mjs (idempotent install, uninstall, fingerprint).
. "$(dirname "$0")/lib.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/cmd-hooks/install-hooks.mjs"

# Use an isolated HOME so we don't touch the real ~/.commandcode
FAKEHOME="$(mktemp -d)"
export HOME="$FAKEHOME"
CC_DIR="$FAKEHOME/.commandcode"
SETTINGS="$CC_DIR/settings.json"
TRUST="$CC_DIR/trusted-hooks.json"

echo "install-hooks.mjs"

# 1. Install creates settings + trust with all 4 events
t_title "install creates hooks for 4 events"
node "$INSTALL" >/dev/null 2>&1
t_assert_eq "0" "$?" "install exit 0"
export SET="$SETTINGS"
node -e '
const fs=require("fs");
const s=JSON.parse(fs.readFileSync(process.env.SET));
const evs=Object.keys(s.hooks);
console.log(evs.join(","));
' > /tmp/evs.txt
t_assert_eq "SessionStart,PreToolUse,PostToolUse,Stop" "$(cat /tmp/evs.txt)" "all four events present"

# 2. Idempotent: second install does not duplicate
t_title "install is idempotent"
node "$INSTALL" >/dev/null 2>&1
node -e '
const fs=require("fs");
const s=JSON.parse(fs.readFileSync(process.env.SET));
const n=s.hooks.SessionStart[0].hooks.length;
console.log(n);
' > /tmp/n.txt
t_assert_eq "1" "$(cat /tmp/n.txt)" "single entry per event"

# 3. trusted-hooks.json has a fingerprint
t_title "trusted-hooks records fingerprint"
export TR="$TRUST"
node -e '
const fs=require("fs");
const t=JSON.parse(fs.readFileSync(process.env.TR));
const all=Object.values(t).flat();
console.log(all.length>0 && all[0].fingerprint ? "yes":"no");
' > /tmp/trust.txt
t_assert_eq "yes" "$(cat /tmp/trust.txt)" "fingerprint recorded"

# 4. Uninstall removes events + trust
t_title "uninstall removes hooks"
node "$INSTALL" --uninstall >/dev/null 2>&1
node -e '
const fs=require("fs");
const s=JSON.parse(fs.readFileSync(process.env.SET));
console.log(Object.keys(s.hooks||{}).length);
' > /tmp/after.txt
t_assert_eq "0" "$(cat /tmp/after.txt)" "no hook events remain"

rm -rf "$FAKEHOME"
summary
