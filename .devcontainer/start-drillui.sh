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
make_public() {
  # Returns 0 only if port 8787 is actually public afterwards.
  #
  # Needs a token with the `codespace` scope in CODESPACE_PORTS_TOKEN, added as
  # a Codespaces secret. The built-in GITHUB_TOKEN is deliberately NOT tried:
  # it lacks the scope, so using it would produce a misleading failure.
  [ -n "${CODESPACE_PORTS_TOKEN:-}" ] || return 1
  [ -n "${CODESPACE_NAME:-}" ] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  GH_TOKEN="$CODESPACE_PORTS_TOKEN" \
    gh codespace ports visibility 8787:public -c "$CODESPACE_NAME" >/dev/null 2>&1 || return 1
  GH_TOKEN="$CODESPACE_PORTS_TOKEN" \
    gh codespace ports -c "$CODESPACE_NAME" 2>/dev/null | grep -q '^.*8787[[:space:]]*public' || return 1
  return 0
}

announce() {
  # Inside a codespace, http://localhost:8787 on the VISITOR's machine is their
  # own machine, not this container — the only address that works is the
  # forwarded one. It is derivable, so print it rather than leaving someone to
  # discover the Ports panel. VS Code makes the URL clickable in the terminal.
  # CODESPACE_NAME is exported into VS Code's own terminals but NOT into every
  # shell (an ssh session, for one), and this banner is worthless if it degrades
  # to a localhost URL that cannot work. The codespace agent always writes the
  # name to a file, so fall back to that before giving up.
  local name="${CODESPACE_NAME:-}" domain="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  local envfile=/workspaces/.codespaces/shared/environment-variables.json
  if [ -z "$name" ] && [ -r "$envfile" ]; then
    name="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("CODESPACE_NAME",""))' "$envfile" 2>/dev/null)"
  fi

  local url=""
  if [ -n "$name" ]; then
    url="https://${name}-8787.${domain}/"
  else
    url="http://localhost:8787/"
  fi
  printf '\n'
  printf '  ┌──────────────────────────────────────────────────────────────┐\n'
  printf '  │  drillui is running on port 8787.                            │\n'
  printf '  └──────────────────────────────────────────────────────────────┘\n'
  printf '\n'
  if make_public; then
    printf '  drillui is PUBLIC on this address — open it in any browser:\n'
    printf '\n    %s\n\n' "$url"
    printf '  Clicking is fine now that the port is public.\n'
  else
    printf '  COPY the address below and PASTE it into a new browser tab:\n'
    printf '\n    %s\n\n' "$url"
    printf '  Do NOT ctrl/cmd-click it, and do not use the PORTS tab button.\n'
    printf '  Every click path is rewritten by VS Code into a much longer\n'
    printf '  .../pf-signin?... URL — a sign-in hand-off that fails in some\n'
    printf '  browsers. The plain address above bypasses it.\n'
    printf '\n'
    printf '  To make clicking work too, add a Codespaces secret named\n'
    printf '  CODESPACE_PORTS_TOKEN (a token with the `codespace` scope) at\n'
    printf '  https://github.com/settings/codespaces — this script then sets\n'
    printf '  the port public on every start.\n'
  fi
  printf '\n'
  printf '  (localhost:8787 will NOT work from your own browser — that\n'
  printf '   address is this container, not your machine.)\n\n'
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
