#!/usr/bin/env bash
# Start drillui on the bundled sample and leave it running.
#
# Runs as postAttachCommand, so it fires every time the codespace is attached
# (including a resume from stopped) — unlike onCreateCommand, which a prebuild
# has already executed and which therefore never runs for the visitor.
#
# Port 8787 is set to onAutoForward "openBrowser" in devcontainer.json, so the
# moment this bridge binds, VS Code opens the terminal UI in the user's browser.
# That is the whole point: two clicks, then drilling — no command to type.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 0          # never fail the attach

DOC="${DRILLUI_DOC:-2305.04710v1.pdf}"
LOG="/tmp/drillui.log"

# Already listening (attach fired twice, or the user started it by hand)? Leave it.
if (exec 3<>/dev/tcp/127.0.0.1/8787) 2>/dev/null; then
  exec 3<&- 2>/dev/null; exec 3>&- 2>/dev/null
  echo "drillui already running on :8787"
  exit 0
fi

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"

if ! command -v bun >/dev/null 2>&1; then
  echo "bun not found — run: bash .devcontainer/onCreate.sh"
  exit 0
fi
[ -f "$DOC" ] || { echo "sample $DOC missing — skipping drillui autostart"; exit 0; }

nohup bun tools/drillui_bridge.ts "$DOC" --host 0.0.0.0 >"$LOG" 2>&1 &
echo "drillui starting on :8787 for $DOC  (log: $LOG)"
