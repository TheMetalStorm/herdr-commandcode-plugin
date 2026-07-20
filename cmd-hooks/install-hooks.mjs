#!/usr/bin/env node
// Install the Command Code -> Herdr status hook into Command Code's settings.
//
// Writes a Claude Code-compatible `hooks` block into ~/.commandcode/settings.json
// (SessionStart + Stop -> cmd-hooks/herdr-status.sh) and records the hook command
// fingerprint in ~/.commandcode/trusted-hooks.json so Command Code trusts it.
//
// Usage: node install-hooks.mjs [--uninstall]

import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";

const HOME = homedir();
const CC_DIR = join(HOME, ".commandcode");
const SETTINGS = join(CC_DIR, "settings.json");
const TRUST = join(CC_DIR, "trusted-hooks.json");

// Absolute path to the hook script next to this installer.
const HOOK = join(dirname(new URL(import.meta.url).pathname), "herdr-status.sh");
const COMMAND = `sh ${HOOK}`;

function sha256slice(s) {
  return createHash("sha256").update(s).digest("hex").slice(0, 16);
}

const uninstall = process.argv.includes("--uninstall");

function readJson(p, fallback) {
  try {
    return JSON.parse(readFileSync(p, "utf8"));
  } catch {
    return fallback;
  }
}

async function main() {
  const fp = await sha256slice(COMMAND);
  const settings = readJson(SETTINGS, {});
  settings.hooks = settings.hooks || {};

  const entry = { hooks: [{ type: "command", command: COMMAND }] };

  for (const ev of ["SessionStart", "PreToolUse", "PostToolUse", "Stop"]) {
    const list = settings.hooks[ev] || [];
    if (uninstall) {
      settings.hooks[ev] = list.filter(
        (e) => !(e.hooks || []).some((h) => h.command === COMMAND)
      );
      if (settings.hooks[ev].length === 0) delete settings.hooks[ev];
    } else {
      const already = list.some((e) =>
        (e.hooks || []).some((h) => h.command === COMMAND)
      );
      if (!already) list.push(entry);
      settings.hooks[ev] = list;
    }
  }

  mkdirSync(CC_DIR, { recursive: true });
  writeFileSync(SETTINGS, JSON.stringify(settings, null, 2) + "\n");

  // Trust the hook command (project root "" = global/user scope is auto-trusted,
  // but record it so future per-project prompts are satisfied).
  const trust = readJson(TRUST, {});
  const roots = Object.keys(trust);
  const root = roots[0] || "";
  trust[root] = (trust[root] || []).filter((r) => r.fingerprint !== fp);
  if (!uninstall) trust[root].push({ fingerprint: fp, trustedAt: new Date().toISOString() });
  writeFileSync(TRUST, JSON.stringify(trust, null, 2) + "\n");

  console.log(
    uninstall
      ? `Removed herdr status hook from ${SETTINGS}`
      : `Installed herdr status hook into ${SETTINGS}\n  command: ${COMMAND}`
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
