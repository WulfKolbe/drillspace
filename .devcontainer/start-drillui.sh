#!/usr/bin/env bash
# Start drillui on the bundled sample and leave it running.
#
# Wired to BOTH postStartCommand and postAttachCommand, deliberately:
#
#   - postStartCommand runs whenever the container starts, with no client
#     involved. This is the one that matters: a codespace created or resumed
#     without an editor attached (gh codespace create, a port-forward, an API
#     call) still ends up with the bridge listening.
#   - postAttachCommand covers the case where a client attaches to a container
#     that was already running when the bridge was not — e.g. after someone
#     killed it by hand.
#
# Running twice is harmless: the port check below turns the second call into a
# no-op. Neither hook is onCreateCommand, which a prebuild has already executed
# and which therefore never runs for a visitor.
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

# setsid, not just nohup. A lifecycle hook's shell exits as soon as the script
# returns, and the codespace agent tears down that process group — which killed
# the bridge every time, leaving a 0-byte log and nothing on 8787. setsid puts
# the bridge in its OWN session so it survives; </dev/null detaches stdin, which
# a background process without a terminal otherwise blocks on.
setsid nohup bun tools/drillui_bridge.ts "$DOC" --host 0.0.0.0 \
  </dev/null >"$LOG" 2>&1 &
disown 2>/dev/null || true

# Confirm it actually bound, rather than reporting success and leaving the user
# to discover otherwise. This is the check that was missing.
announce() {
  # Inside a codespace, http://localhost:8787 on the VISITOR's machine is their
  # own machine, not this container — the only address that works is the
  # forwarded one. It is derivable, so print it rather than leaving someone to
  # discover the Ports panel. VS Code makes the URL clickable in the terminal.
  local url=""
  if [ -n "${CODESPACE_NAME:-}" ]; then
    url="https://${CODESPACE_NAME}-8787.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}/"
  else
    url="http://localhost:8787/"
  fi
  printf '\n'
  printf '  ┌──────────────────────────────────────────────────────────────┐\n'
  printf '  │  drillui is running. Open it here:                           │\n'
  printf '  └──────────────────────────────────────────────────────────────┘\n'
  printf '\n    %s\n\n' "$url"
  printf '  (ctrl/cmd-click the link. localhost:8787 will NOT work from your\n'
  printf '   own browser — that address is this container, not your machine.)\n\n'
}

for _ in $(seq 1 20); do
  if (exec 3<>/dev/tcp/127.0.0.1/8787) 2>/dev/null; then
    exec 3<&- 2>/dev/null; exec 3>&- 2>/dev/null
    announce
    exit 0
  fi
  sleep 1
done
echo "drillui did NOT bind :8787 within 20s — see $LOG"
tail -20 "$LOG" 2>/dev/null
