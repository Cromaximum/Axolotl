# Changelog

Every merged PR adds a line here, newest first, under `Unreleased`. Keep each line short: what
changed and the PR number. When a TestFlight or App Store build ships, move the `Unreleased`
lines under a version heading.

Format: `- YYYY-MM-DD · Area · What changed (#PR)`

## Unreleased

- 2026-11-06 · App · Screens rebuilt to match the concept art (D-010): edge-to-edge photos with text only in the bottom board or a lower-third scrim, wide photos shown whole over a blur, fact cards with the photo on top and a big number, Historical photo / Real fossil / Reconstruction tags on extinct media. New: welcome and starting-point screens, species detail sheet, Feed / Tree / Met tabs, "Species met" collection with saves.
- 2026-11-06 · Design · Added twelve concept screens built from real Wikimedia Commons photos in `docs/design/`, and the "species first, information second" layout rules (D-010).
- 2026-11-06 · Docs · Added AGENTS.md, CLAUDE.md and the `docs/` folder for collaborating agents, with rules that every change updates the docs.
- 2026-11-06 · App · First version of the SwiftUI app: paging feed, zoo-board intro card, photo and fact cards, tree-of-life filter with extinct toggles, live Wikipedia/Commons content with licence filtering, 77 seed species. Pushed directly to `main` (before the PR rule).
