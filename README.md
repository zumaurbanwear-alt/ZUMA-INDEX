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
