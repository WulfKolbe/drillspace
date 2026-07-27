#!/usr/bin/env bash
# pdfdrill playground — container provisioning.
#
# Runs as onCreateCommand, NOT postCreateCommand: Codespaces prebuilds execute
# setup only up to onCreateCommand/updateContentCommand. Anything placed in
# postCreateCommand would be re-run on every codespace creation and would make
# the (paid) prebuild pointless for the ~4 GB TeXLive set.
#
# Single source of truth: the apt package list and the Python deps are NOT
# duplicated here. bootstrap.sh owns them; this script only supplies the
# prerequisites bootstrap.sh assumes (python3/pip/curl) and the runtimes the
# CoCalc script installs the same way (bun, uv), then calls bootstrap.sh.
#
# Idempotent: safe to re-run by hand inside a live codespace.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi

step() { printf '\n== %s ==\n' "$1"; }

# ---- 1/6  Prerequisites bootstrap.sh assumes exist ----------------------
step "1/6  base prerequisites (python3, pip, curl, unzip)"
$SUDO apt-get update -q || true
$SUDO apt-get install -y -q python3 python3-pip python3-venv curl unzip ca-certificates \
  || echo "  (apt-get failed — later steps will report what is missing)"

# --- tesseract: installed HERE, deliberately, ahead of bootstrap.sh ------
# bootstrap.sh asks for `tesseract-ocr-equ`, which does not exist in the
# Ubuntu 24.04 archive (upstream dropped equ.traineddata). apt-get is invoked
# there with the whole package array at once, so that one unknown name aborts
# the ENTIRE transaction — poppler, ghostscript, libvips and all of texlive
# would fail to install, silently (the call is `>/dev/null 2>&1 || echo`).
#
# Installing tesseract first makes bootstrap.sh's `command -v tesseract` guard
# true, so it never adds the bad name and the rest of its list installs.
# `equ` is not a loss: src/pdfdrill/ocr_lines.py already strips it from the
# lang list, and the math second pass uses MATH_LANGS = "ell+eng" — so the
# pack that path actually needs is Greek, which bootstrap.sh never installed.
step "1b/6  tesseract + language packs (eng, deu, ell)"
$SUDO apt-get install -y -q tesseract-ocr tesseract-ocr-eng tesseract-ocr-deu tesseract-ocr-ell \
  || echo "  (tesseract install failed — pdfdrill ocr will be unavailable)"

# bootstrap.sh invokes `pip`, not `pip3`. On Ubuntu 24.04 python3-pip may only
# provide pip3; give it the name it expects rather than patching bootstrap.sh.
if ! command -v pip >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
  $SUDO ln -sf "$(command -v pip3)" /usr/local/bin/pip
  echo "  linked pip -> $(command -v pip3)"
fi

# ---- 2/6  bun (drillui bridge runtime + TiddlyWiki host) ----------------
step "2/6  bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if command -v bun >/dev/null 2>&1; then
  echo "  bun already present: $(bun --version)"
else
  curl -fsSL https://bun.sh/install | bash || echo "  (bun install failed)"
fi
command -v bun >/dev/null 2>&1 && echo "  bun $(bun --version)"

# ---- 3/6  uv + uvx ------------------------------------------------------
step "3/6  uv"
export PATH="$HOME/.local/bin:$PATH"
if command -v uv >/dev/null 2>&1; then
  echo "  uv already present: $(uv --version)"
else
  curl -LsSf https://astral.sh/uv/install.sh | sh || echo "  (uv install failed)"
fi
command -v uv >/dev/null 2>&1 && echo "  uv $(uv --version)"

# ---- 4/6  the repo's own bootstrap (apt set + python deps + doctor) -----
# Installs: poppler-utils, ghostscript, libvips-tools, tesseract(+eng/deu/equ),
# sane-utils, dvisvgm and the full texlive set, then pip -r requirements.txt.
step "4/6  bootstrap.sh"
bash "$ROOT/bootstrap.sh" || echo "  (bootstrap.sh reported problems — see doctor output above)"

# ---- 5/6  deep-zoom image server (pyvips) -------------------------------
# tools/imageserver/install.sh calls plain `pip install`, which Ubuntu 24.04
# refuses (PEP 668, externally-managed-environment). bootstrap.sh passes
# --break-system-packages explicitly; install.sh does not. Rather than edit the
# upstream script, grant the same permission through pip's own environment
# variable, which has identical effect and is scoped to this call.
step "5/6  imageserver (pyvips)"
PIP_BREAK_SYSTEM_PACKAGES=1 bash "$ROOT/tools/imageserver/install.sh" \
  || echo "  (imageserver install failed — re-run: PIP_BREAK_SYSTEM_PACKAGES=1 bash tools/imageserver/install.sh)"

# ---- 6/6  TiddlyWiki, hosted by bun -------------------------------------
# Installed as a bun global package so the `tiddlywiki` binary lands in
# ~/.bun/bin (already on PATH via devcontainer.json remoteEnv). The KaTeX
# plugin ships inside the tiddlywiki package itself; no separate install.
step "6/6  TiddlyWiki (bun global)"
if command -v bun >/dev/null 2>&1; then
  bun add --global tiddlywiki || echo "  (bun add tiddlywiki failed)"
  command -v tiddlywiki >/dev/null 2>&1 \
    && echo "  tiddlywiki $(tiddlywiki --version)" \
    || echo "  tiddlywiki not on PATH yet — open a new shell"
else
  echo "  bun missing — skipping TiddlyWiki"
fi

printf '\n%s\n' "----------------------------------------------------------------"
echo " provisioning finished. Verify with:"
echo "     bash .devcontainer/verify.sh"
printf '%s\n' "----------------------------------------------------------------"
