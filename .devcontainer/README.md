# .devcontainer — how the playground is provisioned

Notes for whoever maintains this container. **Nobody needs to read this to use
drillspace** — the top-level [README](../README.md) is the whole user-facing
story. This file exists so the detail has somewhere to live that is not in a
first-time user's way.

## Files

| File | Role |
|------|------|
| `devcontainer.json` | image, ports, environment, VS Code settings |
| `onCreate.sh` | one-time provisioning, run as `onCreateCommand` |
| `verify.sh` | diagnostic; independent named tests, exit status = failure count |

## Why `onCreateCommand` and not `postCreateCommand`

Codespaces prebuilds execute setup only up to `onCreateCommand` /
`updateContentCommand`. Anything in `postCreateCommand` re-runs on *every*
codespace creation, which would make a prebuild pointless for the ~4 GB TeX
set. Keep provisioning where it is.

Configure prebuilds at **Settings → Codespaces → Set up prebuild**. Note a
**fork does not inherit** the upstream repo's prebuilds.

## The preflight gate is disabled here — deliberately

`devcontainer.json` sets `PDFDRILL_NO_PREFLIGHT=1`.

pdfdrill ships an attestation gate (`src/pdfdrill/preflight.py`) that
hard-blocks every build/extract command until the caller proves it read
`SKILL.md`, by echoing back a checksum token. It exists for a real reason:
pdfdrill's prose output looks authoritative, so an **LLM** that skimmed the
SKILL can produce confidently-wrong extractions.

That reasoning does not transfer to a human who clicked a link to try a PDF.
For them the gate is a wall of refusal (`⛔ pdfdrill STOP:`) in place of a
result, on the very first command — the exact opposite of what this repo is
for. The gate stays fully intact in pdfdrill itself; it is switched off only
inside the playground container.

If you are driving pdfdrill from an agent **in this container** and want the
gate back, unset the variable for that shell:

```bash
env -u PDFDRILL_NO_PREFLIGHT python3 -m pdfdrill <cmd> <pdf>
```

## PATH: why three mechanisms

`bun`, `uv` and `tiddlywiki` install under `$HOME` (`/home/vscode/...`), which
is not on the default `PATH`. Each mechanism alone has a failure mode, so all
three are used:

1. **`devcontainer.json` `remoteEnv`** — applies to VS Code and what it spawns.
   This previously interpolated `${containerEnv:HOME}`, which reads the
   *image's* environment; the base image sets no `HOME`, so it expanded to
   empty and produced the dead entry `/.bun/bin`. It is now a literal, pinned
   by `"remoteUser": "vscode"`.
2. **`~/.bashrc`** — covers interactive terminals. bun's installer usually
   writes such a block itself, but skips it in some non-interactive installs,
   so we do not depend on that.
3. **`/usr/local/bin` symlinks** (`onCreate.sh` step 7/7) — the backstop.
   First on every default `PATH`, independent of `HOME`, rc files,
   login-vs-interactive shells and `remoteEnv`. This is the layer that
   actually guarantees resolution.

### T8 in `verify.sh`

T1 and T7 resolve binaries using whatever `PATH` the caller happened to have,
so a tool can pass there and still be missing from a fresh terminal. That is
exactly how a `bun: command not found` once slipped past a provisioning run
that reported success.

T8 re-resolves `bun`, `uv` and `tiddlywiki` via `env -i` — a shell inheriting
nothing — and so reproduces what a new terminal actually sees. `onCreate.sh`
prints the same clean-shell check at the end of provisioning, putting the
failure in the creation log rather than in a confused user's terminal.

## Known upstream quirks handled here

- **`tesseract-ocr-equ` does not exist** in the Ubuntu 24.04 archive. `bootstrap.sh`
  passes its whole package array to one `apt-get` call, so that single unknown
  name would abort the entire transaction — poppler, ghostscript, libvips and
  all of TeXLive — silently. `onCreate.sh` installs tesseract *first* so
  `bootstrap.sh`'s `command -v tesseract` guard is true and the bad name is
  never added.
- **`pip` vs `pip3`** — `bootstrap.sh` invokes `pip`; Ubuntu 24.04's
  `python3-pip` may provide only `pip3`. `onCreate.sh` symlinks it.
- **PEP 668** — `tools/imageserver/install.sh` calls plain `pip install`, which
  Ubuntu 24.04 refuses. `onCreate.sh` sets `PIP_BREAK_SYSTEM_PACKAGES=1` for
  that call rather than patching the upstream script.
