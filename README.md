# ZÜMA — INDEX

Editorial / archive-style landing page for ZÜMA. Static site, no build
step required — open `index.html` (or serve the folder) directly.

- `index.html` — English homepage
- `fr.html` — Français homepage
- `collections/00X-name/` — one Collection Archive page per drop,
  linked from the homepage's Collections section and Archive table
- `templates/collection-archive/` — the master template; duplicate
  this folder to publish a new collection (see
  `docs/ARCHITECTURE.md` → "Collection Archives")

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

The IPSEITY archive page (`collections/001-ipseity/`) references six
product photos (`images/muerted-zephyr.png`, `images/front-tee-1.png`,
`images/full-look-1.png`, `THE GAZE 222222.png`,
`images/front-tee-2.png`, `images/full-look-2.png`) that were not
included in the source project this refactor was built from. Drop the
real files in at those paths (relative to the site root) to fill the
grid — everything else is already wired up correctly. Every other
Collection Archive section is an intentional placeholder (see
`styles/components/archive-placeholder.css`) — that's by design, not
a gap: the owner fills those in manually per the brief.
