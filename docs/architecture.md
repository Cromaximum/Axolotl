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
  Features/Components/       Shared card pieces: full-bleed image, chips, rail, status bar
  Features/Feed/            Feed screen and card views
  Features/Detail/          Species detail sheet
  Features/Met/             "Species met" collection and its store
  Features/Onboarding/      Welcome and starting-point screens
  Features/Picker/          Tree-of-life filter screen (Tree tab) and persisted preferences
  Resources/taxonomy.json   Bundled tree of life + species list (generated, do not hand-edit)
AnimalScrollerTests/        XCTest unit tests for the pure-logic services
.github/                    CI workflow (`workflows/ios.yml`) and PR template
```

## File map

| File | Responsibility |
| --- | --- |
| `App/AnimalScrollerApp.swift` | `@main`. Loads taxonomy, creates `PreferencesStore` and `MetStore`, sets a 64 MB / 512 MB `URLCache`, forces dark mode. |
| `App/RootView.swift` | Onboarding until `hasOnboarded`, then the Feed / Tree / Met `TabView`. |
| `App/Theme.swift` | Palette, font helpers (fall back to system font), `BoardPanel` framed sign view, `Color(hex:)`. |
| `Models/Taxon.swift` | `Taxon` tree node, `Species`, `ConservationStatus`, `SpeciesEntry` (species + lineage), tree queries, `TaxonomyLoader`. |
| `Models/FeedCard.swift` | `Attribution`, `LicensedImage`, `FeedCard` enum (`intro` / `fact` / `photo`) and card payloads. |
| `Services/WikiClient.swift` | Raw HTTP to Wikipedia REST (summary) and Action API (plain-text extract, article images with `extmetadata`). |
| `Services/SpeciesContent.swift` | `SpeciesContent` value type, `SpeciesContentProvider` protocol, `WikipediaContentProvider` actor (live fetch + in-memory cache; `.shared` is used by the feed, onboarding tiles and detail sheet). |
| `Services/ContentPolicy.swift` | Licence allowlist, junk-image filter, artwork detection, `HTMLText.plain`. |
| `Services/FactExtractor.swift` | Splits article into sections, scores sentences, picks up to 8 standalone facts (max 2 per section). |
| `Services/SpeciesPicker.swift` | Chooses the next species: tailored vs discovery, novelty and dwell-time affinity weighting, recent-repeat window. |
| `Services/FeedComposer.swift` | Turns one species' content into intro + up to 8 alternating photo/fact cards. |
| `Features/Feed/FeedViewModel.swift` | `@MainActor` feed state: restart on filter change, prefetch, dwell tracking, retry up to 4 species per load, each card's position in its set. |
| `Features/Feed/FeedView.swift` | Paging `ScrollView` under the status bar, pull to refresh, records species met, save (rail or long-press), opens the detail sheet. |
| `Features/Feed/CardContext.swift` | Position in set, saved state and Save / Info callbacks passed to each card. |
| `Features/Feed/IntroCardView.swift` | Full-bleed hero with the zoo-board sign at the bottom. |
| `Features/Feed/PhotoCardView.swift` | Edge-to-edge photo, name pill, action rail; media tag + scrim caption for extinct species. |
| `Features/Feed/FactCardView.swift` | Photo on top, fact board below with the stand-out number (`FactFormatting`). |
| `Features/Components/CardComponents.swift` | `FullBleedImage` (top-anchored fill, or shown whole over blur when wide), `CreditChip` + `AttributionDetail`, `MediaTagChip`, `NamePill`, `ProgressDashes`, `ActionRail`, `DidYouKnowBox`, `ConservationScale`, `LowerThirdScrim`, `CardInsets`. |
| `Features/Detail/SpeciesDetailView.swift` | Species detail sheet; loads `SpeciesContent` through the shared provider. |
| `Features/Met/MetStore.swift` | `@Observable` species-met collection persisted to `UserDefaults` (`met.v1`). |
| `Features/Met/MetView.swift` | "Species met" grid with All / Saved / Extinct. |
| `Features/Onboarding/OnboardingView.swift` | Welcome, starting-point tiles (`StartingPoint`), `SpeciesPhoto` (licensed hero for a species). |
| `Features/Picker/PreferencesStore.swift` | `@Observable` filter state persisted to `UserDefaults`, `ExtinctMode`, `hasOnboarded`. |
| `Features/Picker/TaxonomyPickerView.swift` | Tree tab: extinct three-way switch, toggles, tree-of-life outline. |

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
