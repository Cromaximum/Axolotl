# Architecture

This file is the map of the code as it is. The rules for what may be added (layers, dependency
rules, naming, where new features go, and the review gate) are in
[architecture-rules.md](architecture-rules.md). Read both before writing code.

SwiftUI app, iOS 17, Swift 5.9, Observation framework (`@Observable`), async/await. No
third-party dependencies. The Xcode project is generated from `project.yml` by XcodeGen.

## Repo layout

```
AGENTS.md, CLAUDE.md        Agent entry points (read first)
README.md                   Human quick start
project.yml                 XcodeGen spec (targets, bundle ids, Info.plist keys)
docs/                       Project docs (this folder)
tools/species.txt           The species to include (Wikipedia titles); the only hand-made data input
tools/gen_taxonomy.py       Builds Resources/taxonomy.json from Wikidata + Wikipedia
tools/taxonomy-sources.json Generated provenance for every taxonomy value
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
| `App/AnimalScrollerApp.swift` | `@main`. Loads taxonomy, creates the stores, the live catalogue, one `URLSession` (16 MB / 512 MB `URLCache`), one `ImagePipeline` and one `CachingContentProvider` over `WikipediaContentProvider`, injects them (`.environment(\.imageLoader)`, `.environment(\.speciesContentProvider)`), forces dark mode. |
| `App/RootView.swift` | Onboarding until `hasOnboarded`, then the Feed / Tree / Met `TabView`. |
| `App/Theme.swift` | Palette, font helpers (fall back to system font), `BoardPanel` framed sign view, `Color(hex:)`. |
| `Models/Taxon.swift` | `Taxon` tree node, `Species`, `ConservationStatus`, `SpeciesEntry` (species + lineage), tree queries, `TaxonomyLoader`. |
| `Models/FeedCard.swift` | `Attribution`, `LicensedImage`, `FeedCard` enum (`intro` / `fact` / `photo`) and card payloads. |
| `Services/WikiClient.swift` | Raw HTTP to Wikipedia REST (summary) and Action API (plain-text extract, article images with `extmetadata`). |
| `Services/SpeciesContent.swift` | `SpeciesContent` value type, `SpeciesContentProvider` protocol, `WikipediaContentProvider` (live fetch only, client injected). `.shared` is deprecated and still used by onboarding tiles and the detail sheet until W3 switches them to the environment provider; delete it then. |
| `Services/CachingContentProvider.swift` | Decorator over any `SpeciesContentProvider`: memory cache, disk cache (`Caches/species-content.v1/`), one shared in-flight fetch per species, stale copy when offline. |
| `Services/ContentCachePolicy.swift` | Pure rules for that cache: 7-day freshness, schema, file names (FNV-1a hash of the title), outdated folders. |
| `Services/ImagePipeline.swift` | `ImageLoading` protocol and `ImagePipeline` actor: fetch through the injected session, downsample with ImageIO off the main thread, cost-limited memory cache of decoded images, shared fetches, prefetch. |
| `Services/ImageSizing.swift` | Pure sizing: full-screen decode size, Wikimedia thumbnail width (1280), cache keys and costs. |
| `Services/ContentPolicy.swift` | Licence allowlist, junk-image filter, artwork detection, `HTMLText.plain`. |
| `Services/FactExtractor.swift` | Splits article into sections, scores sentences, picks up to 8 standalone facts (max 2 per section). |
| `Services/SpeciesPicker.swift` | Chooses the next species: tailored vs discovery, novelty, dwell-time and like affinity weighting, recent-repeat window. For the live catalogue: `pickBranch` (which tree branch to search, fewer tries on branches that came back empty) and `choose` (among live candidates, also weighted by article length). |
| `Services/GBIFClient.swift` | Raw HTTP to the GBIF species API: match a bundled taxon name to a backbone key, page through accepted species under a key. |
| `Services/SpeciesCatalog.swift` | `SpeciesCatalog` protocol, `LiveCandidate`, and the `LiveSpeciesCatalog` actor: random GBIF page → one batched Wikipedia check → candidates; `finalize` adds the Wikidata IUCN status for the pick. One instance is created in `AnimalScrollerApp` and injected through `RootView` → `FeedView` → `FeedViewModel` (no singleton). |
| `Services/LiveCatalogRules.swift` | Pure rules for live species: article quality gate (`accepts`), content quality gate (`isShowable`), common name from the article title, status mapping, lineage building (bundled nodes + `gbif-…` nodes), searchable branches, inside/outside split, random offset, popularity weight. Also `Taxon.path(to:)` and `Taxon.Rank.depth`. |
| `Services/FeedSourcePlanner.swift` | Pure: for each load attempt, which source to try (bundled list, live catalogue, or live then bundled). About half live while bundled species in scope are unseen; live-only after that; the last attempt is always bundled. |
| `Services/LikeAffinity.swift` | Pure: liked lineages → interest per taxon id (genus 2.5, family 2, order 1, class 0.4). |
| `Services/FeedComposer.swift` | Turns one species' content into intro + up to 8 alternating photo/fact cards. |
| `Features/Feed/FeedViewModel.swift` | `@MainActor` feed state: restart on filter change, up to two species loads in flight, image prefetch for the next 3 cards, dwell tracking, retry up to 4 species per load, stamps `CardPlacement` on each set, `FeedNotice` (no matches / offline). Logs time to first card and a signpost per species fetch (`os`, category `feed`). `emptyMessage` and `positions` are compatibility accessors until W2's `FeedView` switches. |
| `Features/Feed/FeedView.swift` | Paging `ScrollView` under the status bar, pull to refresh, records species met, save (rail or long-press), opens the detail sheet. |
| `Features/Feed/CardContext.swift` | Position in set, saved state and Save / Info callbacks passed to each card. |
| `Features/Feed/IntroCardView.swift` | Full-bleed hero with the zoo-board sign at the bottom. |
| `Features/Feed/PhotoCardView.swift` | Edge-to-edge photo, name pill, action rail; media tag + scrim caption for extinct species. |
| `Features/Feed/FactCardView.swift` | Photo on top, fact board below with the stand-out number (`FactFormatting`). |
| `Features/Components/FullBleedImage.swift` | Full-bleed photo (top-anchored fill, or shown whole over blur when wide), drawn from the injected `ImageLoading` through `RemoteImageModel`. |
| `Features/Components/RemoteImageModel.swift` | `@MainActor` state for one remote image; shows a prefetched image without a placeholder flash. |
| `Features/Components/AppEnvironment.swift` | `imageLoader` and `speciesContentProvider` environment values. Defaults fail and log a fault instead of reaching the network. |
| `Features/Components/CardComponents.swift` | `CreditChip` + `AttributionDetail`, `MediaTagChip`, `NamePill`, `ProgressDashes`, `ActionRail`, `DidYouKnowBox`, `ConservationScale`, `LowerThirdScrim`, `CardInsets`. |
| `Features/Detail/SpeciesDetailView.swift` | Species detail sheet; loads `SpeciesContent` through the shared provider. |
| `Features/Met/MetStore.swift` | `@Observable` species-met collection persisted to `UserDefaults` (`met.v1`). |
| `Features/Likes/LikesStore.swift` | `@Observable` liked species persisted to `UserDefaults` (`likes.v1`); exposes `affinity` for the picker. Injected into the environment by `AnimalScrollerApp`. |
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
LikesStore.affinity ──────────────────┤
                                     ▼
                     FeedViewModel.loadMore()  (follows FeedSourcePlanner)
                    ┌────────────────┴─────────────────┐
     bundled pick (about half while         live pick (liveCatalog on)
     bundled species are unseen)            SpeciesPicker.pickBranch() ─▶ bundled Taxon branch
     SpeciesPicker.next()                   LiveSpeciesCatalog.candidates()
                    │                          ├─ GBIFClient.key / species (random page of ~40)
                    │                          └─ WikiClient.probeArticles (one batched query)
                    │                       LiveCatalogRules.accepts / lineage
                    │                       SpeciesPicker.choose() ─▶ LiveCandidate
                    │                       LiveSpeciesCatalog.finalize() (Wikidata P141 status)
                    └────────────────┬─────────────────┘
                                     ▼ SpeciesEntry
                                     │
                                     ▼
            SpeciesContentProvider.content(for:)   (CachingContentProvider: memory → disk → network)
                                     │  wraps WikipediaContentProvider
               ├─ WikiClient.summary / plainTextArticle / images
               ├─ FactExtractor.facts
               └─ ContentPolicy.licensedImages
                                     │ SpeciesContent
                                     ▼
                     FeedComposer.cards() ──▶ [FeedCard] appended to feed
                                     │
                     FeedView renders; cardAppeared() records dwell, prefetches species,
                     and ImageLoading.prefetch()es the next cards' photos
                     FullBleedImage ◀─ ImagePipeline (decoded, downsampled, memory-cached)
                     heart / double-tap ─▶ LikesStore (steers the next pick)
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
- New species: add its English Wikipedia title to `tools/species.txt`, run
  `python3 tools/gen_taxonomy.py`, update the species count
  in [status.md](status.md).
