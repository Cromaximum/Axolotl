# Roadmap

From the concept deck, plus work identified since. Tick items off (and move them to
[changelog.md](changelog.md)) as they merge. Add new items where they belong.

## Phase 1: Prove the loop

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
- [ ] Architecture follow-ups from the #4 review: now W1 steps 4 to 6 and W3 steps 3 and 4 below
- [ ] Grow to a few hundred reviewed species (likely generated from Wikidata, then human-reviewed)
- [x] Live species catalogue from the GBIF Backbone with on-the-fly cards (D-012; needs a simulator check against the live APIs)
- [x] Likes that steer tailored picks (D-013)
- [ ] Widen the live catalogue: add more class/order/family branches to the bundled tree so GBIF is searched in more places
- [ ] Liked filter in the Met tab (W3)
- [ ] Remove all AI-written content (D-011), see [ai-content-audit.md](ai-content-audit.md)
- [ ] Static content pipeline: batch job builds one JSON file per species (taxonomy from GBIF or
      Catalogue of Life linked to Wikidata ids → fetch Commons/Wikipedia/IUCN → licence and
      quality filter → facts drafted from Wikipedia, cited, reviewed by a person → publish to a
      CDN). Only species that pass every check ship. Plug in as a new `SpeciesContentProvider`.
- [x] Bundle Fredoka and Nunito Sans fonts (W2, #13)
- [ ] Bundle a Nunito Sans italic face for scientific names (system italic until then)
- [ ] Real support contact in the Wikimedia `User-Agent`
- [ ] Choose the shipping name (must not use "Instagram")
- [ ] Privacy manifest, app icon, TestFlight build

## Phase 1.5: Polish and performance (current, from 2026-11-06)

Maxwell got the app running on 2026-11-06 and asked for a round of optimisation and UX work. The
architect split it into four workstreams that **own separate files**, so they can run in
parallel without merge conflicts. Each one still follows the gate (design note before code,
`Architecture review: Approved` before merge; see [architecture-rules.md](architecture-rules.md)).

**File ownership rule:** only edit files your workstream owns. If you need a change in another
stream's file, ask that stream (or the architect) instead of editing it. Shared docs
(`changelog.md`, `status.md`, `roadmap.md`) are open to everyone: keep both sides when they
conflict. Every stream owns accessibility (VoiceOver labels, Dynamic Type, Reduce Motion,
contrast) for its own files.

### W1 · Feed speed and data plumbing

Owns: `App/AnimalScrollerApp.swift`, `Services/WikiClient.swift`, `Services/SpeciesContent.swift`,
`Services/GBIFClient.swift`, `Services/SpeciesCatalog.swift`, new `Services/ImagePipeline.swift`
(or similar), `Models/`, `Features/Feed/FeedViewModel.swift`, `Features/Feed/CardContext.swift`,
new `Stores/`, and `FullBleedImage` (move it out of `CardComponents.swift` into
`Features/Components/FullBleedImage.swift` as the first commit).

1. [x] Image pipeline: replace `AsyncImage` in `FullBleedImage` with a loader that has a memory
       cache, downsamples to screen size, and prefetches the images of the next few cards. (#14)
2. [x] Persist `SpeciesContent` to a disk cache so relaunching and revisiting are instant. (#14)
3. [ ] Measure and tune prefetch distance, parallel species loads, and time to first card.
       #14 adds two parallel loads, image prefetch and `os` logging ("Time to first card",
       "Species content" signposts, category `feed`). Still needs numbers from a simulator run.
4. [ ] Inject one `SpeciesContentProvider` from `App/` (environment value), and remove
       `WikipediaContentProvider.shared` and the `FeedViewModel` default. W3 switches its views over.
       W1 may change only the init-signature lines in `FeedView` and `RootView` for this, after
       telling W2 and W3. Done in #14 except `.shared`, which is deprecated until W3 switches
       Onboarding and Detail, then deleted.
5. [x] Move `PreferencesStore`, `MetStore` and `LikesStore` to `Stores/` (file moves only), after
       W3's PR A (new `MetStore.Entry`) merges. (#16)
6. [x] Put set position and count on the card payload instead of `FeedViewModel.positions`.
       Keep a compatible accessor until W2 has switched `FeedView` over. (#14: `FeedCard.placement`, `primaryImage`)

### W2 · Feed feel: motion, gestures, visuals

Owns: `Features/Feed/FeedView.swift`, `IntroCardView.swift`, `PhotoCardView.swift`,
`FactCardView.swift`, `Features/Components/CardComponents.swift` (except `FullBleedImage`),
`App/Theme.swift`, `project.yml`, and new `Resources/Fonts/`.

1. [x] Bundle Fredoka and Nunito Sans (OFL, already in `docs/design/concept-art/fonts`) and
       register them in `project.yml`.
2. [x] Loading placeholders that look like the board (no bare spinners), plus friendly empty
       and offline states with retry.
3. [x] Paging feel: snap, card transitions, the like burst and save feedback, and haptics
       (`sensoryFeedback`). Honour Reduce Motion.
4. [x] Dynamic Type and VoiceOver pass on every card. Text must never cover the animal (D-010).
5. [x] Switch `FeedView` to W1's card position fields when they land.

### W3 · Onboarding, Tree, detail and Met screens

Owns: `App/RootView.swift`, `Features/Onboarding/`, `Features/Picker/TaxonomyPickerView.swift`,
`Features/Detail/`, `Features/Met/MetView.swift`, and `MetStore.Entry`'s shape (coordinate the
file move with W1).

1. [x] Tree tab: search by common or scientific name, species counts per branch, a summary of
       what's selected, and "reset to everything".
2. [ ] Met tab: Liked filter, sort, and a faster grid using W1's image pipeline. (Liked filter and sort done in #11; grid on W1's image loader comes in PR B.)
3. [x] `MetStore.Entry` keeps only id, dates and flags, and looks names up when shown (needs a
       `met.v2` key or a tolerant decoder; update data-model.md).
4. [ ] Onboarding: small view model for tile photos using the injected provider (after W1 step
       4). Same for `SpeciesDetailView`.
5. [ ] Detail sheet polish: sections, sources list, open-in-Wikipedia.

### W4 · Content quality and variety

Also owns the `gen_taxonomy.py --lint` step in `.github/workflows/ios.yml` (architect, 2026-11-06).
Owns: `Services/FactExtractor.swift`, `Services/ContentPolicy.swift`,
`Services/FeedComposer.swift`, `Services/SpeciesPicker.swift`, `Services/LikeAffinity.swift`,
`Services/LiveCatalogRules.swift`, `Services/FeedSourcePlanner.swift`, `tools/`,
`Resources/taxonomy.json`, and their tests. All pure logic or generated data, no views.

1. [ ] Better facts: drop sentences that need context ("It", "This species" openers),
       references, and lists; prefer sentences with numbers. Verbatim only (D-011).
2. [ ] Better photos: skip near-duplicates and low-resolution files, prefer the lead image,
       and pace the feed (no three photos in a row).
3. [ ] Grow `tools/species.txt` toward a few hundred species, and add class/order/family
       branches so the live catalogue searches more of the tree.
4. [ ] Tune the picker and likes so the feed feels varied: no same family back to back,
       30% discovery kept (D-001).
5. [ ] Add `gen_taxonomy.py --check` to CI once the cache can be committed.

### Not assigned yet

- [ ] Run on a physical iPhone and fix device-only issues
- [ ] Real support contact in the Wikimedia `User-Agent`
- [ ] Choose the shipping name; privacy manifest, app icon, TestFlight build

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
