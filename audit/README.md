# The audit wiki

`pdfdrill-audit.html` is a single-file TiddlyWiki holding three documents drilled
by different routes, with each document's `inspect` and `report` output stored as
tiddlers so they open **inside** the wiki rather than as separate files.

| bibkey | what it is | route |
|---|---|---|
| `2209.00445v3` | arXiv, LaTeX-gold source available | the good path |
| `1012.3259` | arXiv, PDF-only submission, no LaTeX | no gold column to check against |
| `USRE41428` | US reissue patent, scanned | OCR, page images throughout |

661 tiddlers, 24.8 MB.

## Opening it in the Codespace

It is a local file — no server, no build step:

```bash
python3 -m http.server 8000 --directory audit
```

then open `http://localhost:8000/pdfdrill-audit.html` on the forwarded port. Or
just open the file from the editor's file explorer.

Serving it matters for one thing only: the three **source PDF** links are
`_canonical_uri` references to `files/`, relative to the wiki. Over `file://`
some browsers refuse those; over `http://` they work.

### Where to start

Search `results/USRE41428.inspect`. That is the scanned patent — the hardest of
the three — and its inspector is a complete standalone document with its own
element tree and 19 embedded page images, rendered inside the tiddler.

## Why it lives here and not on pdfdrill.github.io

GitHub Pages' legacy builder cannot process a repo containing a file this size
within its ten-minute limit — measured, twice: 32 MB timed out at 10m24s and
24.8 MB at 10m30s, and every build failed until the file was removed. A wiki
this size is something you open locally anyway, which is exactly what a
Codespace is for.

## Known rough edge

One leftover `application/pdf` tiddler still points at
`files/6788_Riemannian_Generative_Dec.pdf`, from a fourth document whose other
tiddlers were removed. That PDF is not bundled — it is 15 MB — so the entry does
not resolve. The paper is *Riemannian Generative Decoder*, TMLR 04/2026:
<https://openreview.net/forum?id=vuPMXg1FDT>

**Do not hand-edit this file.** Round-trip changes through TiddlyWiki itself and
save from there; editing the tiddler store as raw text keeps the JSON parseable
while still corrupting the wiki, so the usual checks pass and the damage lands
anyway.
