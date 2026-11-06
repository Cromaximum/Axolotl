# Architecture

SwiftUI app, iOS 17, Swift 5.9, Observation framework (`@Observable`), async/await. No
third-party dependencies. The Xcode project is generated from `project.yml` by XcodeGen.

## Repo layout

```
AGENTS.md, CLAUDE.md        Agent entry points (read first)
README.md                   Human quick start
project.yml                 XcodeGen spec (targets, bundle ids, Info.plist keys)
docs/                       Project docs (this folder)
tools/gen_taxonomy.py       Generates Resources/taxonomy.json from a Python tree literal
AnimalScroller/
  App/                      App entry point, Theme (palette, fonts, BoardPanel)
  Models/                   Taxon, Species, ConservationStatus, SpeciesEntry, FeedCard types
  Services/                 Content fetching, licence policy, fact extraction, picking, composing
  Features/Feed/            Feed screen and card views
  Features/Picker/          Tree-of-life filter screen and persisted preferences
  Resources/taxonomy.json   Bundled tree of life + species list (generated, do not hand-edit)
AnimalScrollerTests/        XCTest unit tests for the pure-logic services
.github/                    CI workflow (`workflows/ios.yml`) and PR template
```

## File map

| File | Responsibility |
| --- | --- |
| `App/AnimalScrollerApp.swift` | `@main`. Loads taxonomy, creates `PreferencesStore`, sets a 64 MB / 512 MB `URLCache`, forces dark mode. |
| `App/Theme.swift` | Palette, font helpers (fall back to system font), `BoardPanel` framed sign view, `Color(hex:)`. |
| `Models/Taxon.swift` | `Taxon` tree node, `Species`, `ConservationStatus`, `SpeciesEntry` (species + lineage), tree queries, `TaxonomyLoader`. |
| `Models/FeedCard.swift` | `Attribution`, `LicensedImage`, `FeedCard` enum (`intro` / `fact` / `photo`) and card payloads. |
| `Services/WikiClient.swift` | Raw HTTP to Wikipedia REST (summary) and Action API (plain-text extract, article images with `extmetadata`). |
| `Services/SpeciesContent.swift` | `SpeciesContent` value type, `SpeciesContentProvider` protocol, `WikipediaContentProvider` actor (live fetch + in-memory cache). |
| `Services/ContentPolicy.swift` | Licence allowlist, junk-image filter, artwork detection, `HTMLText.plain`. |
| `Services/FactExtractor.swift` | Splits article into sections, scores sentences, picks up to 8 standalone facts (max 2 per section). |
| `Services/SpeciesPicker.swift` | Chooses the next species: tailored vs discovery, novelty and dwell-time affinity weighting, recent-repeat window. |
| `Services/FeedComposer.swift` | Turns one species' content into intro + up to 8 alternating photo/fact cards. |
| `Features/Feed/FeedViewModel.swift` | `@MainActor` feed state: restart on filter change, prefetch, dwell tracking, retry up to 4 species per load. |
| `Features/Feed/FeedView.swift` | Paging `ScrollView`, pull to refresh, filter sheet. |
| `Features/Feed/IntroCardView.swift` | Zoo-sign intro card, IUCN status bar, `ArtworkTag`. |
| `Features/Feed/PhotoCardView.swift` | Full-bleed photo card. |
| `Features/Feed/FactCardView.swift` | "Did you know?" fact board. |
| `Features/Feed/AttributionBadge.swift` | Credit chip and credit sheet. |
| `Features/Picker/PreferencesStore.swift` | `@Observable` filter state persisted to `UserDefaults`. |
| `Features/Picker/TaxonomyPickerView.swift` | Tree-of-life outline with toggles. |

## Data flow

```
taxonomy.json ──TaxonomyLoader──▶ Taxon tree
                                     │
PreferencesStore (filters) ──────────┤
                                     ▼
                     FeedViewModel.loadMore()
                                     │ tailored + everything lists
                                     ▼
                     SpeciesPicker.next()  ──▶ SpeciesEntry
                                     │
                                     ▼
            SpeciesContentProvider.content(for:)   (WikipediaContentProvider today)
               ├─ WikiClient.summary / plainTextArticle / images
               ├─ FactExtractor.facts
               └─ ContentPolicy.licensedImages
                                     │ SpeciesContent
                                     ▼
                     FeedComposer.cards() ──▶ [FeedCard] appended to feed
                                     │
                     FeedView renders; cardAppeared() records dwell + triggers prefetch
```

## Design principles

- **Pure logic in `Services/`, testable without network.** `FeedComposer`, `SpeciesPicker`,
  `FactExtractor` and `ContentPolicy` are value types or enums with no I/O. Keep it that way and
  add tests when you change them.
- **Content source is swappable.** Anything that produces `SpeciesContent` can implement
  `SpeciesContentProvider`. The planned static JSON pipeline should be a new provider, not a
  rewrite of the feed.
- **Policy is enforced at ingestion.** Images that fail `ContentPolicy` never reach a card.
- **Views are dumb.** Decisions about what to show live in services and the view model.

## Adding things

- A new card type: add a case to `FeedCard`, a payload struct, a view in `Features/Feed/`,
  composition logic in `FeedComposer`, and tests. Update [product.md](product.md) and
  [data-model.md](data-model.md).
- A new content source: implement `SpeciesContentProvider`, inject it into `FeedViewModel`,
  and update [content-and-licensing.md](content-and-licensing.md) first.
- New species: edit `tools/gen_taxonomy.py`, run
  `python3 tools/gen_taxonomy.py AnimalScroller/Resources/taxonomy.json`, update the species count
  in [status.md](status.md).
