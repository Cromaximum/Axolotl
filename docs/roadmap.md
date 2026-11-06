# Roadmap

From the concept deck, plus work identified since. Tick items off (and move them to
[changelog.md](changelog.md)) as they merge. Add new items where they belong.

## Phase 1: Prove the loop (current)

Goal: TestFlight beta with open-licensed images and Wikipedia facts.

- [x] Zoo-board intro, photo and fact cards
- [x] Tree-of-life filter with extinct toggles
- [x] Live Wikipedia / Commons content with licence filtering
- [x] 77 seed species
- [x] Screens rebuilt to the concept art (D-010): full-bleed photos, welcome and starting-point
      screens, species detail sheet, Feed / Tree / Met tabs, "Species met" collection with saves
- [x] CI: build and test on every PR (PR #1)
- [x] First successful compile and test run; fix build errors (#5)
- [ ] Run on a device and fix layout / behaviour issues
- [ ] Grow to a few hundred reviewed species (likely generated from Wikidata, then human-reviewed)
- [x] Live species catalogue from the GBIF Backbone with on-the-fly cards (D-012, proposed; needs a simulator check against the live APIs)
- [x] Likes that steer tailored picks (D-013)
- [ ] Widen the live catalogue: add more class/order/family branches to the bundled tree so GBIF is searched in more places
- [ ] Liked filter in the Met tab
- [ ] Remove all AI-written content (D-011): regenerate species data from Wikidata, add an
      AI-image filter, see [ai-content-audit.md](ai-content-audit.md)
- [ ] Static content pipeline: batch job builds one JSON file per species (taxonomy from GBIF or
      Catalogue of Life linked to Wikidata ids → fetch Commons/Wikipedia/IUCN → licence and
      quality filter → facts drafted from Wikipedia, cited, reviewed by a person → publish to a
      CDN). Only species that pass every check ship. Plug in as a new `SpeciesContentProvider`.
- [ ] Bundle Fredoka and Nunito Sans fonts
- [ ] Real support contact in the Wikimedia `User-Agent`
- [ ] Choose the shipping name (must not use "Instagram")
- [ ] Privacy manifest, app icon, TestFlight build

## Phase 2: Motion and memory

- Commons video clips and animal sounds (needs licensing rules update first)
- ~~Saves and a "species seen" collection (persisted)~~ Pulled into Phase 1 with the concept screens.
- Feed learns from time spent (persist dwell affinity; likes are already persisted)
- Ads SDK integration
- App Store launch

## Phase 3: Partner footage

- Licensed clips from zoos, museums and filmmakers
- Creator credit pages
- Accounts and sharing
- Quizzes and species streaks
