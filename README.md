# ZÜMA — INDEX

Editorial / archive-style landing page for ZÜMA. Static site, no build
step required — open `index.html` (or serve the folder) directly.

- `index.html` — English
- `fr.html` — Français

## Structure

See `docs/ARCHITECTURE.md` for the full breakdown of `styles/`,
`scripts/`, and `assets/`, plus the reasoning behind every refactor
decision. See `docs/CLEANUP.md` for the list of dead code removed.

## Local development

No dependencies, no bundler. Any static file server works, e.g.:

```
python3 -m http.server 8000
```

Then visit `http://localhost:8000/index.html`.

## Known gap

The Lookbook section references six product photos
(`images/muerted-zephyr.png`, `images/front-tee-1.png`,
`images/full-look-1.png`, `THE GAZE 222222.png`,
`images/front-tee-2.png`, `images/full-look-2.png`) that were not
included in the source project this refactor was built from. Drop the
real files in at those paths (relative to the site root) to fill the
grid — everything else is already wired up correctly.

# ZÜMA INDEX — Architecture

This document explains how the codebase is organized and the reasoning
behind every non-obvious decision made during the refactor from a single
1.8MB `index.html` (and its `fr.html` twin) into this modular project.

## Starting point

The original files were ~98% inlined base64 image data. Once that's
stripped out, the *actual* markup + CSS + JS was ~32KB — a small,
well-written single-page site. That made a full modular split practical
without any framework or build step.

## Folder structure

```
ZUMA-INDEX/
├── index.html            English page
├── fr.html                French page (/fr.html, linked from nav)
├── assets/
│   ├── images/             hero-bg.png (extracted from base64)
│   ├── logos/               favicon
│   ├── fonts/ textures/ icons/ audio/   reserved, currently empty
├── styles/
│   ├── core/                reset, design tokens, globals, typography
│   ├── layout/               nav, section chrome, footer, responsive
│   ├── components/          loader, buttons, texture-bands, cards
│   ├── animations/           shared keyframes, scroll-reveal system
│   └── pages/                one file per page section
├── scripts/
│   ├── core/loader.js        intro splash logic
│   └── animations/reveal.js  IntersectionObserver scroll-reveal
├── data/ templates/ scripts/{ui,pages,archive}/   reserved, currently empty
└── docs/
```

`data/`, `templates/`, and the empty `scripts/` subfolders are kept as
placeholders per the requested architecture, ready for future work
(e.g. moving the Archive table rows into `data/drops.json` once there's
more than two rows, or a `templates/section.html` partial if a
templating/build step is introduced later).

## Stylesheet load order matters

`styles/layout/responsive.css` is always linked **last** in both HTML
files. It's the only stylesheet where load order affects the rendered
result: its `@media (max-width: 768px)` rules share the same specificity
as their base-file counterparts, so it has to lose the "declared last
wins" tie-break in its favor, exactly as it did as the last block in the
original single `<style>` tag. Every other file's order is cosmetic.

## Why class names were **not** renamed to BEM

The brief asked for BEM-style class names, but also states as an
absolute rule that DOM output must stay identical and the site must
render pixel-perfect. Those two requirements conflict: a class name is
part of the DOM, and this project had no way to visually re-render and
diff the page during the refactor (no browser/screenshot tool in this
environment).

Given that, correctness was prioritized over naming: **every class name,
id, and element tag from the original markup was kept verbatim.** I
verified this by structurally diffing the new HTML's `<body>` against
the original body (tags + attributes + text, whitespace/comments
ignored) — they match exactly except for the two documented, zero-risk
cleanups below.

If you want the BEM pass done as a true, isolated step, it's a
mechanical follow-up now that the CSS is already split into small files
— happy to do it with visual review (screenshots) once that's
available, since renaming touches HTML, CSS *and* nothing in JS (no
class names are queried from `scripts/`).

## Two verbatim-but-harmless structural fixes

1. **A stray extra `</div>` after the loader markup** in the original
   source (with no matching open tag) was dropped. Browsers ignore
   unmatched closing tags, so this was a zero-effect no-op either way —
   removing it just keeps the new markup valid.
2. **Two separate `.footer-right` CSS rules** (declared ~100 lines apart
   in the original, one `{display:flex;...}`, one
   `{text-align:right;position:relative;z-index:2;}`) were merged into a
   single rule in `styles/layout/footer.css`. They shared no conflicting
   properties, so the computed style is identical regardless of source
   order — merging just removes a duplicate selector.

## Missing lookbook images

The Lookbook section's `<img>` tags reference `images/muerted-zephyr.png`,
`images/front-tee-1.png`, `images/full-look-1.png`, `THE GAZE 222222.png`,
`images/front-tee-2.png`, and `images/full-look-2.png`. **None of these
files were present in the uploaded project** (only `android-chrome-512x512.png`
and the two inlined base64 backgrounds existed). Their `src` paths have
been preserved exactly as-is rather than pointed at `assets/images/`,
since moving a reference to a file that doesn't exist here either way
has no effect — but preserving the original path means dropping the
real files into place later (`images/muerted-zephyr.png` etc., relative
to the site root) will make them work with zero further changes.

## See also

- `docs/CLEANUP.md` — every piece of dead code that was removed, and why
  each one is confirmed safe to remove.

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


