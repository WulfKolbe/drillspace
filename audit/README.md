# The audit wiki

`pdfdrill-audit.html` is a single-file TiddlyWiki holding three documents drilled
by different routes, with the `inspect` and `report` output that exists for them
stored as tiddlers so it opens **inside** the wiki rather than as separate files.

| bibkey | what it is | route | inlined output |
|---|---|---|---|
| `2209.00445v3` | arXiv, LaTeX-gold source available | the good path | `report` |
| `1012.3259` | arXiv, PDF-only submission, no LaTeX | no gold column to check against | `inspect` + `report` |
| `USRE41428` | US reissue patent, scanned | OCR, page images throughout | none — 19 page images only |

660 tiddlers, 22.8 MB.

Byte-identical to the copy served at
<https://pdfdrill.github.io/pdfdrill-audit.html>. Keep it that way: both come
from the same build, and a divergence between them is a bug, not a variant.

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

Search `results/1012.3259.inspect`. That is the PDF-only arXiv submission — no
LaTeX to check the extraction against — and its inspector is a complete
standalone document with its own element tree and 17 page images, rendered
inside the tiddler.

## It is also on pdfdrill.github.io now

An earlier version of this file said it could not be. That was true of the
**legacy** Pages builder, which fetches the whole repository and timed out at
ten minutes — measured twice, 32 MB at 10m24s and 24.8 MB at 10m30s. The site
now builds from a GitHub Actions workflow with a shallow checkout, which
publishes the same artifact in well under a minute. The copy here is for
working offline in the Codespace, not because the hosted one is impossible.

## Known rough edges

- One leftover `application/pdf` tiddler still points at
  `files/6788_Riemannian_Generative_Dec.pdf`, from a fourth document whose other
  tiddlers were removed. That PDF is not bundled — it is 15 MB — so the entry
  does not resolve. The paper is *Riemannian Generative Decoder*, TMLR 04/2026:
  <https://openreview.net/forum?id=vuPMXg1FDT>
- `kolbe2018hubbard.inspect.html` is in the store (7.7 MB, a third of the file)
  but nothing links to it. The index tiddler lists results with
  `[tag[drillhtml]prefix[results/…]]`, and that tiddler has neither the tag nor
  the prefix, so it is reachable only by searching its exact title.
- The index tiddler's own heading and table still describe **four** documents,
  including a `RiemannianGD` row with 157 tiddlers. Those tiddlers are gone;
  the counts in that table no longer add up to what is in the store.

**Do not hand-edit this file.** Round-trip changes through TiddlyWiki itself and
save from there; editing the tiddler store as raw text keeps the JSON parseable
while still corrupting the wiki, so the usual checks pass and the damage lands
anyway.
