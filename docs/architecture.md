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
tools/gen_taxonomy.py       Builds Resources/taxonomy.json from Wikidata + Wikipedia; --screen checks new titles (D-019)
tools/taxonomy-sources.json Generated provenance for every taxonomy value
AnimalScroller/
  App/                      App entry point, Theme (palette, fonts, BoardPanel)
  Models/                   Taxon, Species, ConservationStatus, SpeciesEntry, FeedCard types
  Services/                 Content fetching, licence policy, fact extraction, picking, composing
  Features/Components/       Shared card pieces: full-bleed image, chips, rail, status bar
  Features/Feed/            Feed screen and card views
  Features/Detail/          Species detail sheet
  Stores/                   App-wide persisted state: PreferencesStore, MetStore, LikesStore, AchievementsStore
  Features/Met/             "Species met" collection
  Features/Achievements/    Awards tab (tiered achievements for species met) and the tier toast
  Features/Onboarding/      Welcome and starting-point screens
  Features/Picker/          Tree-of-life filter screen (Tree tab)
  Resources/taxonomy.json   Bundled tree of life + species list (generated, do not hand-edit)
AnimalScrollerTests/        XCTest unit tests for the pure-logic services
.github/                    CI workflow (`workflows/ios.yml`) and PR template
```

## File map

| File | Responsibility |
| --- | --- |
| `App/AnimalScrollerApp.swift` | `@main`. Loads taxonomy, creates the stores, the live catalogue, one `URLSession` (16 MB / 512 MB `URLCache`), one `ImagePipeline` and one `CachingContentProvider` over `WikipediaContentProvider`, injects them (`.environment(\.imageLoader)`, `.environment(\.speciesContentProvider)`), forces dark mode. |
| `App/RootView.swift` | Onboarding until `hasOnboarded`, then the Feed / Tree / Met / Awards `TabView`. Builds the `TaxonomyIndex` once and passes it to the Tree, Met, Awards and onboarding screens; on appear, drops stored copies of live species the bundled tree now covers (`MetStore.forgetCopies`). Owns the `AchievementsViewModel`: refreshes it on appear and whenever the number of species met changes, shows its toast over the tabs and the unseen-tier badge on the Awards tab. |
| `App/Theme.swift` | Palette, bundled font names and helpers (`Theme.FontName`, `heading`, `body(size, weight:)`, `label`, `scientific`), `Theme.Motion` animation constants, `Color(hex:)`. |
| `Models/Taxon.swift` | `Taxon` tree node, `Species`, `ConservationStatus`, `SpeciesEntry` (species + lineage), tree queries, `TaxonomyLoader`. |
| `Models/Achievement.swift` | `Achievement` (kind: overall, a tree node, or an IUCN status; name from the taxonomy or the status label; bundled group size; `group` for sectioning) and `AchievementProgress` (met count, reached targets = tier, next target). |
| `Models/FeedCard.swift` | `Attribution`, `LicensedImage`, `FeedCard` enum (`intro` / `fact` / `photo`) and card payloads. |
| `Services/WikiClient.swift` | Raw HTTP to Wikipedia REST (summary) and Action API (plain-text extract, article images with `extmetadata`). |
| `Services/SpeciesContent.swift` | `SpeciesContent` value type, `SpeciesContentProvider` protocol, `WikipediaContentProvider` (live fetch only, client injected). `.shared` is deprecated and still used by onboarding tiles and the detail sheet until W3 switches them to the environment provider; delete it then. |
| `Services/CachingContentProvider.swift` | Decorator over any `SpeciesContentProvider`: memory cache, disk cache (`Caches/species-content.v1/`), one shared in-flight fetch per species, stale copy when offline. |
| `Services/ContentCachePolicy.swift` | Pure rules for that cache: 7-day freshness, schema, file names (FNV-1a hash of the title), outdated folders. |
| `Services/ImagePipeline.swift` | `ImageLoading` protocol and `ImagePipeline` actor: fetch through the injected session, downsample with ImageIO off the main thread, cost-limited memory cache of decoded images, shared fetches, prefetch. |
| `Services/ImageSizing.swift` | Pure sizing: full-screen decode size, Wikimedia thumbnail width (1920, a standard Wikimedia step), cache keys and costs. |
| `Services/ContentPolicy.swift` | Licence allowlist, junk-image filter (file names and Commons categories), artwork detection, size floors, `licensedImages` (filters, then ranks with `PhotoQuality`), `HTMLText.plain`. |
| `Services/PhotoQuality.swift` | Pure photo ranking (Commons Featured/Quality/Valued, resolution, portrait fit, close-up and specimen signals, lead image) and the choice between Wikimedia's 1920 px and 3840 px/original renditions so photos are sharp full screen. |
| `Services/FactExtractor.swift` | Splits article into sections, scores sentences, picks up to 8 standalone facts (max 2 per section). |
| `Services/SpeciesPicker.swift` | Chooses the next species: tailored vs discovery, novelty, dwell-time and like affinity weighting, recent-repeat window. For the live catalogue: `pickBranch` (which tree branch to search, fewer tries on branches that came back empty) and `choose` (among live candidates, also weighted by article length). |
| `Services/GBIFClient.swift` | Raw HTTP to the GBIF species API: match a bundled taxon name to a backbone key, page through accepted species under a key. |
| `Services/SpeciesCatalog.swift` | `SpeciesCatalog` protocol, `LiveCandidate`, and the `LiveSpeciesCatalog` actor: random GBIF page → one batched Wikipedia check → candidates; `finalize` adds the Wikidata IUCN status for the pick. One instance is created in `AnimalScrollerApp` and injected through `RootView` → `FeedView` → `FeedViewModel` (no singleton). |
| `Services/LiveCatalogRules.swift` | Pure rules for live species: article quality gate (`accepts`), content quality gate (`isShowable`), common name from the article title, status mapping, lineage building (bundled nodes + `gbif-…` nodes), searchable branches, inside/outside split, random offset, popularity weight. Also `Taxon.path(to:)` and `Taxon.Rank.depth`. |
| `Services/FeedSourcePlanner.swift` | Pure: for each load attempt, which source to try (bundled list, live catalogue, or live then bundled). About half live while bundled species in scope are unseen; live-only after that; the last attempt is always bundled. |
| `Services/LikeAffinity.swift` | Pure: liked lineages → interest per taxon id (genus 2.5, family 2, order 1, class 0.4). |
| `Services/TaxonomyIndex.swift` | Pure, built once from the bundled tree: node and species lookup by id, `path(to:)`, species count per branch, nodes by rank and all species in tree order (`taxa(rank:)`, `allEntries`), selection state (selected / covered by a parent / partly selected), selection summary in tree order, and case- and accent-insensitive name search (exact, prefix, word prefix, substring; branches before species on a tie). |
| `Services/HeroImage.swift` | Pure: which licensed image stands for a species outside the feed (lead image, else first real photo, else any usable; artwork only for extinct species when allowed). Same rule as `FeedComposer`'s intro hero. |
| `Services/AchievementTiers.swift` | Pure: tier targets for a group size. Ladder 1, 5, 10, 25, 50, then every 50; starts at about a twentieth of the group; adds the group size as a "met them all" target unless a ladder value is within 20%; never runs out. |
| `Services/AchievementBoard.swift` | Pure: the achievements the bundled tree offers (every species; each phylum, class and order with 3+ bundled species; each IUCN status from EX to LC that some bundled species has), progress from a list of met `SpeciesEntry`s (counted by lineage node id, so live species count through their bundled branches), sections, newly reached tiers, unseen tiers. |
| `Services/MetCollection.swift` | Pure: resolves stored Met records to `SpeciesEntry` values (bundled data wins; live records only for species not in the tree), then filters (All / Saved / Liked / Extinct) and sorts (recently seen, first met, name, group). |
| `Services/FeedComposer.swift` | Turns one species' content into intro + up to 8 alternating photo/fact cards. |
| `Features/Feed/FeedViewModel.swift` | `@MainActor` feed state: restart on filter change, up to two species loads in flight, image prefetch for the next 3 cards, dwell tracking, retry up to 4 species per load, stamps `CardPlacement` on each set, `FeedNotice` (no matches / offline). Logs time to first card and a signpost per species fetch (`os`, category `feed`). |
| `Features/Feed/FeedView.swift` | Paging `ScrollView` with full-screen pages (content padded above the tab bar) and a scroll transition. Tracks the card on screen with `scrollPosition(id:)`, which drives dwell, prefetch and species met; a restart scrolls back to the top. Pull to refresh, like (heart or double-tap) and save (rail or long-press) with haptics and a toast, VoiceOver actions per card, opens the detail sheet. |
| `Features/Feed/FeedStatusView.swift` | The page after the last card: `BoardPlaceholder` while loading, or a board for the `FeedNotice`: no matches (points to the Tree tab) or offline (with Try again). |
| `Features/Feed/FeedFeedback.swift` | `FeedFeedback` (last like/save → haptic and toast text) and the `FeedbackToast` capsule. |
| `Features/Feed/CardContext.swift` | Position in set, saved state and Save / Info callbacks passed to each card. |
| `Features/Feed/IntroCardView.swift` | Full-bleed hero with the zoo-board sign at the bottom. |
| `Features/Feed/PhotoCardView.swift` | Edge-to-edge photo, name pill, action rail; media tag + scrim caption for extinct species. |
| `Features/Feed/FactCardView.swift` | Photo on top, fact board below with the stand-out number (`FactFormatting`). |
| `Features/Components/FullBleedImage.swift` | Full-bleed photo (top-anchored fill, or shown whole over blur when wide), drawn from the injected `ImageLoading` through `RemoteImageModel`; `ShimmerFill` while loading. |
| `Features/Components/RemoteImageModel.swift` | `@MainActor` state for one remote image; shows a prefetched image without a placeholder flash. |
| `Features/Components/AppEnvironment.swift` | `imageLoader` and `speciesContentProvider` environment values. Defaults fail and log a fault instead of reaching the network. |
| `Features/Components/CardComponents.swift` | `CreditChip` + `AttributionDetail`, `MediaTagChip`, `NamePill`, `ProgressDashes`, `ActionRail`, `DidYouKnowBox`, `ConservationScale`, `LowerThirdScrim`, `CardInsets` (incl. `maxBoardShare`). |
| `Resources/Fonts/` | Fredoka and Nunito Sans `.ttf` files with their OFL licences and a README. Registered under `UIAppFonts` in `project.yml`. |
| `Features/Components/SpeciesThumbnail.swift` | A species' hero photo cropped into a small tile (Met grid, onboarding tiles), decoded at tile size; decorative. |
| `Features/Components/SpeciesThumbnailModel.swift` | `@MainActor` state for one thumbnail: content from the injected provider → `HeroImage` → image loader at `ImageSizing.maxPixelSize`. |
| `Features/Components/BoardPanel.swift` | `BoardPanel` framed sign view (moved from `Theme.swift`). |
| `Features/Components/BoardPlaceholder.swift` | `ShimmerFill` (loading fill, static under Reduce Motion) and `BoardPlaceholder` (the intro board drawn as empty bars). |
| `Features/Detail/SpeciesDetailView.swift` | Species detail sheet in sections: header photo with credit, names, quick facts, Did you know?, About, More facts, "Read the full article on Wikipedia", Sources, Classification. Try again on failure. |
| `Features/Detail/SpeciesDetailViewModel.swift` | Loads content through the injected `speciesContentProvider`, picks the hero, builds the facts and the ordered sources list. |
| `Stores/MetStore.swift` | `@Observable` species-met collection persisted to `UserDefaults` (`met.v2`, migrates `met.v1`). Keeps ids, dates and flags; a `LiveRecord` only for live-catalogue species. No image URL: tiles load photos from the provider's cache. `recordMet(_:imageURL:)` / `toggleSaved(_:imageURL:)` remain as deprecated forwarders until `FeedView` calls `recordMet(_:)` / `toggleSaved(_:)`. |
| `Stores/LikesStore.swift` | `@Observable` liked species persisted to `UserDefaults` (`likes.v1`); exposes `affinity` for the picker. Injected into the environment by `AnimalScrollerApp`. |
| `Features/Met/MetView.swift` | "Species met" grid with All / Saved / Liked / Extinct and a sort menu; any tile, live species included, opens the detail sheet. |
| `Features/Met/MetViewModel.swift` | Filter and sort state; maps `MetStore` entries to `MetCollection` records. |
| `Features/Achievements/AchievementsView.swift` | Awards tab: tiers reached, sections (All species, Conservation status, Phyla, Classes, Orders), a row per achievement with an SF Symbol rosette medal (bronze, silver, gold, then amber), progress bar and "NEW" tag. Also `AchievementMedal`, `AchievementText` (UI wording) and `AchievementToastView`. |
| `Features/Achievements/AchievementsViewModel.swift` | Resolves `MetStore` entries (through `MetCollection.resolve`) and builds the board; shows a 3-second toast when a tier goes up after the first refresh; on tab open, remembers which achievements are new and marks every tier seen in `AchievementsStore`. |
| `Stores/AchievementsStore.swift` | `@Observable` highest tier seen per achievement id, persisted to `UserDefaults` (`achievements.v1`). Never lowers a tier. Progress itself is not stored. |
| `Features/Onboarding/OnboardingView.swift` | Welcome (full-bleed hero with credit), starting-point tiles (`StartingPoint`, `SpeciesThumbnail`), photo-credits sheet. Looks names up in the `TaxonomyIndex`. |
| `Features/Onboarding/OnboardingViewModel.swift` | Step, picked tiles, hero images for the welcome screen and credits (injected provider), and the pure tiles → preferences mapping. |
| `Stores/PreferencesStore.swift` | `@Observable` filter state persisted to `UserDefaults`, `ExtinctMode`, `hasOnboarded`. |
| `Features/Picker/TaxonomyPickerView.swift` | Tree tab: search, "Showing" summary with remove and "Reset to everything", extinct three-way switch, toggles, tree-of-life outline with species counts. |
| `Features/Picker/TaxonomyPickerViewModel.swift` | Search text and results, row and summary state from the `TaxonomyIndex`. |

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
               └─ ContentPolicy.licensedImages (filter) → PhotoQuality (rank, pick rendition)
                                     │ SpeciesContent
                                     ▼
                     FeedComposer.cards() ──▶ [FeedCard] appended to feed
                                     │
                     FeedView renders; cardAppeared() records dwell, prefetches species,
                     and ImageLoading.prefetch()es the next cards' photos
                     FullBleedImage ◀─ ImagePipeline (decoded, downsampled, memory-cached)
                     heart / double-tap ─▶ LikesStore (steers the next pick)

MetStore.entries ──(count changes)──▶ RootView ─▶ AchievementsViewModel.refresh()
      MetCollection.resolve ─▶ AchievementBoard.progress (AchievementTiers per group)
      ─▶ toast over the tabs + Awards tab; AchievementsStore keeps the tiers already seen
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
