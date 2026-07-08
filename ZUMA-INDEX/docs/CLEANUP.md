# Cleanup Log

Everything removed during the refactor, and the evidence it was safe to
remove (i.e. it had **zero** effect on the rendered page).

Each item below was confirmed unused by searching for its class name
across both `index.html` and `fr.html`'s markup — none of these
selectors matched any element in either page.

| Removed selector(s) | Where it lived | Note |
|---|---|---|
| `.band-top-r` | texture bands | never applied to any element |
| `.band-ghost--right` | texture bands | never applied to any element |
| `.band-ghost--bottom` | texture bands | never applied to any element |
| `.lb-cross` (+ `::before` / `::after`) | lookbook | never applied to any element |
| `.lb-ph` | lookbook | never applied to any element |
| `.footer-shop-btn` (+ `:hover`) | footer | duplicate of `.hero-shop-btn`; no element used it |
| `.footer-bg-img` | footer | pointed at a background photo, but the `<div class="footer-bg-img">` element it needed didn't exist in either page's markup — the image never rendered |

## Preserved, not deleted

`.footer-bg-img`'s source photo (originally inlined as base64, ~220KB)
is kept at `docs/legacy-unused-assets/footer-bg.png` rather than
permanently discarded, in case the missing `<div>` was an oversight
rather than intentional and someone wants to wire it back up later.

## Not touched

Two things looked like they *might* be dead code but are intentionally
left alone:

- **`.reveal-d4` / `.reveal-d5`** are used on two `.manifesto-block`
  elements but have no matching CSS rule (only `.reveal-d1`–`.reveal-d3`
  exist). Those two blocks just get the base `.reveal` transition with
  no extra delay. This is how the original behaved too — preserved
  as-is rather than "fixed," per the pixel-perfect requirement.
- **The six Lookbook `<img>` `src` paths** that don't resolve to a file
  in this project (see `docs/ARCHITECTURE.md`) — these were already
  broken in the source upload, not something introduced here.
