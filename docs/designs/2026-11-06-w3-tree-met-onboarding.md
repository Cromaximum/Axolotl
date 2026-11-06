# Design: W3 Tree search, Met collection, slim saves, onboarding and detail

- Author: Claude (W3 thread "Improve onboarding, tree and saves"), for Maxwell Rhinelander
- Date: 2026-11-06
- Status: Design approved (architect review on #11, 2026-11-06). PR A coded on the same branch; PR B follows W1 step 4.

## Problem

Phase 1.5 workstream W3 ([roadmap.md](../roadmap.md#phase-15-polish-and-performance-current-from-2026-11-06)).
Maxwell asked for a round of UX polish after first running the app. W3 covers the non-feed
screens:

1. Tree tab: search by common or scientific name, species counts per branch, a summary of what's
   selected, and "reset to everything". Today every row calls `taxon.allSpecies().count` and
   every row walks the tree to work out "inherited" selection, so the list does O(n²) work per
   redraw.
2. Met tab: a Liked filter, sort options, and a grid that doesn't re-fetch tile images.
3. `MetStore.Entry` copies names, extinct flag and an image URL onto the device. That breaks the
   "stores keep ids, not content" rule: regenerated data (D-011) leaves stale text behind. Also,
   tapping a Met tile for a live-catalogue species does nothing, because `MetView` only looks up
   bundled species.
4. Onboarding tiles and `SpeciesDetailView` reach `WikipediaContentProvider.shared` from a view
   `.task`. Move that into small view models that take the injected provider (after W1 step 4).
5. Detail sheet polish: clear sections, a full sources list, and an "Open in Wikipedia" button.

## Where it goes

Two PRs from this design, so step 4 doesn't block the rest:

**PR A (steps 1 to 3), can start right away**

| File | Layer | Responsibility |
| --- | --- | --- |
| `Services/TaxonomyIndex.swift` (new) | Services, pure | Built once from the bundled `Taxon` root. O(1) `node(id)`, `path(to:)`, species count per node, `isCovered(id, by: selection)`, `search(query)` over common and scientific names of nodes and species (case and diacritic insensitive, prefix-of-word match first), and `summary(selection)` (selected nodes in tree order with their counts). Replaces the `Taxon.find` extension that lives in `TaxonomyPickerView.swift` today. |
| `Services/MetCollection.swift` (new) | Services, pure | `enum MetCollection`: `filter` (all, saved, liked, extinct), `sort` (recent, oldest, A to Z, by class), and `resolve` from stored entries to display items using `TaxonomyIndex` plus the stored live record. Static functions only. |
| `Features/Picker/TaxonomyPickerViewModel.swift` (new) | Feature | `@Observable @MainActor`. Holds the search text and debounced results, and exposes row state (selected, covered, partial, count) from the index. Intent methods call `PreferencesStore.toggle` and a new `reset`. |
| `Features/Picker/TaxonomyPickerView.swift` | Feature | Dumb view: `.searchable`, summary chips section with "Reset to everything", outline with cached counts. Search results are a flat list with each hit's path ("Chordates › Mammals"), and a species hit selects its family. |
| `Features/Met/MetViewModel.swift` (new) | Feature | Filter and sort state, calls `MetCollection`. |
| `Features/Met/MetView.swift` | Feature | Dumb view: segmented filter with Liked, sort menu, `LazyVGrid` of tiles keyed by id. Tiles use W1's image view (`FullBleedImage` after W1 step 1) instead of a bare `AsyncImage`, so they share its cache. Tapping any tile, live species included, opens the detail sheet. |
| `Features/Met/MetStore.swift` | Store (moves to `Stores/` in W1 step 5) | New `Entry` shape and `met.v2` key with a one-time migration from `met.v1`. Public methods keep their names so `FeedView` (W2) needs no change. |
| `App/RootView.swift` | App | Creates the index once and passes it to the Tree and Met views. Passes `LikesStore` ids to Met. |

**PR B (steps 4 and 5), after W1 step 4 merges**

| File | Responsibility |
| --- | --- |
| `Features/Onboarding/OnboardingViewModel.swift` (new) | Loads the tile and welcome photos through the injected `SpeciesContentProvider`. Picks the hero with the same rule the feed uses. |
| `Features/Onboarding/OnboardingView.swift` | Tiles read photos from the view model. No `.shared`. The fixed photo species per tile stay as ids (wiki titles), not content. |
| `Features/Detail/SpeciesDetailViewModel.swift` (new) | Loads content through the injected provider, picks the hero, builds the ordered sources list (text, classification, status, every image credit). |
| `Features/Detail/SpeciesDetailView.swift` | Sections: header photo, names and status, "Did you know?", "About" (lead), "More facts", "Classification" (lineage), "Sources". An "Open in Wikipedia" button. Retry on failure. |

## Data flow

- Tree: `taxonomy.json` → `TaxonomyIndex` (built once in `RootView`) → `TaxonomyPickerViewModel`
  (+ `PreferencesStore` selection) → view.
- Met: `MetStore.entries` (ids, dates, flags) + `LikesStore` liked ids + `TaxonomyIndex` →
  `MetCollection.resolve/filter/sort` → `MetViewModel` → grid. Tile photo: species → provider
  (W1's disk-cached content and image pipeline) → lead image URL. Until W1 lands, the tile keeps
  `imageURL` from the stored entry (see contracts).
- Detail and onboarding: species → injected `SpeciesContentProvider` → `ContentPolicy`-checked
  `SpeciesContent` → view model → view. No new content path.

## New contracts

`MetStore.Entry` under a new key `met.v2`:

```swift
struct Entry: Codable, Identifiable, Hashable {
    let id: String            // Species.wikiTitle
    var firstMet: Date
    var lastMet: Date         // new, for "recently met" sort
    var saved: Bool
    var savedAt: Date?        // new, for sorting saves
    var live: LiveRecord?     // only for live-catalogue species not in taxonomy.json
}
struct LiveRecord: Codable, Hashable {
    var species: Species      // as the catalogue returned it (GBIF name, Wikidata status)
    var lineageIDs: [String]  // bundled tree nodes above it
}
```

- Bundled species keep no names, no status and no image URL. They are looked up in the index
  every time, so regenerating `taxonomy.json` updates them.
- A live species can't be looked up offline, so it keeps the `Species` value the catalogue built
  from GBIF/Wikidata/Wikipedia. That is sourced data, not a copy of generated text, and it is the
  same thing `LikesStore` already keeps for likes. If a later `taxonomy.json` gains the species, the
  bundled record wins and `live` is ignored.
- Hero image URL: dropped once W1's provider cache can answer it cheaply. If W1's step 2 hasn't
  merged when PR A is ready, I keep an optional `imageURL` as a cache hint (never shown as
  content, only fetched) and remove it in PR B. Architect's call.
- Migration: on init, if `met.v2` is missing and `met.v1` exists, decode v1 tolerantly, keep
  `id`, `firstMet` and `saved`, set `lastMet = firstMet`, and keep a `live` record only for ids
  not in the taxonomy (built from the v1 names, flagged as unknown status if not extinct). Write
  v2, then remove v1. The decoder is tolerant (every new field optional) so later additions don't
  need a v3.
- `MetStore.init` gains a `knownIDs: Set<String>` (or the index) parameter for the migration.
  `recordMet` and `toggleSaved` take a `SpeciesEntry` instead of `Species` plus `imageURL`. That
  touches two call sites in `FeedView.swift` (W2's file). I'll keep the old signatures as thin
  overloads so W2 can switch when convenient, or ask W2 to change the two lines. Architect's call.
- `PreferencesStore` gains `reset()` (selection empty, extinct "include", surprise on). Its
  stored format is unchanged. W1 owns the file move; this is one method.
- No new dependencies, no new content sources.

## Content rules

- No new source. Everything still enters through the provider and `ContentPolicy`.
- Search only matches names that are already in `taxonomy.json` (generated from Wikidata and
  Wikipedia, D-011). The UI adds chrome only: "Search the tree", "Reset to everything",
  "Selected", sort names, section titles, "Open in Wikipedia".
- No animal names, groups or statuses hard-coded in Swift. Onboarding tile species are ids
  (wiki titles), as today.
- The detail sources list shows every attribution, including the GBIF and Wikidata lines the
  sheet already has.

## Accessibility

- Tree rows: one element, label "<name>, <rank>, <n> species", value "selected", "included by
  <parent>" or "partly selected", and a toggle action. The summary chips are buttons that
  deselect.
- Met tiles: label with name and saved/liked state; the sort menu and filter are labelled.
- Detail: section headers get `.isHeader`. Dynamic Type: no fixed-height text frames (the
  current `factTile` uses `minHeight`, fine). Reduce Motion: onboarding step transition becomes a
  fade.
- Contrast: `Theme.mist` on `Theme.forest` for small captions is checked against 4.5:1 and bumped
  to parchment where it fails (Theme is W2's file, so I use existing colours only).

## Tests

- `TaxonomyIndexTests`: counts match `allSpecies()`, covered/partial logic, search by common,
  scientific and accented names, ordering (prefix matches first), summary order.
- `MetCollectionTests`: each filter and sort, resolve for bundled, live and unknown ids.
- `MetStoreTests`: v1 → v2 migration (bundled and live ids), tolerant decode of a v2 blob with
  missing fields, `toggleSaved` keeps `firstMet`, using an in-memory `UserDefaults` suite.
- PR B: `SpeciesDetailViewModel` and `OnboardingViewModel` with a fake provider (hero choice,
  artwork hidden for living species, failure state, sources list order).

## Open questions

Answered by the architect on #11: (1) yes, both new pure files are W3's; (2) keep `imageURL` as a
fetch-only hint until PR B; (3) deprecated forwarders, W2 switches the `FeedView` call sites;
(4) PR A merges before W1 moves the stores. `PreferencesStore.reset()` keeps the artwork and
full-catalogue switches as they are.

1. Is `Services/TaxonomyIndex.swift` and `Services/MetCollection.swift` OK as new W3-owned files?
   (W4 owns the existing Services files; these are new and independent.)
2. Keep `imageURL` on the Met entry until W1's disk cache lands, or drop it now?
3. `FeedView` call sites: overloads in `MetStore`, or ask W2 to change two lines?
4. Order with W1 step 5 (file move to `Stores/`): I'd like PR A to merge first, or W1 moves the
   file and I rebase. Either works; git follows the rename.
