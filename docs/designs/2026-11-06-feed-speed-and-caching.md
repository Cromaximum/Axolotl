# Design: Feed speed, image pipeline and content caching (Phase 1.5 W1)

- Author: Claude (thread "Speed up feed loading and caching"), asked for by Maxwell Rhinelander
- Date: 2026-11-06
- Status: Design approved (architect, PR #14)

## Problem

Maxwell got the app running on 2026-11-06 and asked for a round of optimisation and UX work. This
is workstream W1 in [roadmap.md](../roadmap.md#w1--feed-speed-and-data-plumbing). Today:

- `FullBleedImage` uses `AsyncImage`: no memory cache, full-size decode of ~1080 px wide JPEGs on
  the main thread per appearance, and nothing is fetched before the card is on screen, so each
  swipe can show a spinner.
- `WikipediaContentProvider` caches `SpeciesContent` in memory only. Every relaunch refetches
  three Wikipedia requests per species before the first card can show.
- The feed loads one species at a time; the next species only starts when the user is within six
  cards of the end.
- `WikipediaContentProvider.shared` is a singleton outside `App/`, reached from `FeedViewModel`'s
  default argument, `OnboardingView` and `SpeciesDetailView` (rules 3 and 4).
- `PreferencesStore`, `MetStore`, `LikesStore` live under `Features/`.
- `FeedViewModel.positions` is a parallel dictionary next to `cards` (size-limit rule).

## Where it goes

Delivered on this PR (#14) as one commit per step, because this thread works on a single branch. Step 5 waits for W3's PR A. Each commit keeps the app working.

| Step | File | Layer | Responsibility |
| --- | --- | --- | --- |
| 0 | `Features/Components/FullBleedImage.swift` | Shared UI | `FullBleedImage` moved out of `CardComponents.swift` unchanged (first commit) |
| 1 | `Services/ImagePipeline.swift` | Service (adapter) | `protocol ImageLoading: Sendable` plus `actor ImagePipeline`: fetch through an injected `URLSession` (whose `URLCache` is the disk cache), downsample with ImageIO to a max pixel size, keep decoded `CGImage`s in a cost-limited LRU memory cache, and coalesce duplicate in-flight requests |
| 1 | `Services/ImageSizing.swift` | Service (pure) | `enum ImageSizing`: target pixel size for a view size and scale, and the cache key. Unit-tested |
| 1 | `Features/Components/RemoteImageModel.swift` | Shared UI | Small `@Observable @MainActor` model owned by `FullBleedImage`: `load(url:)` asks `ImageLoading`, exposes `phase` (loading / image / failed). The view only calls `model.load` from `.task(id:)` |
| 1 | `Features/Components/AppEnvironment.swift` | Shared UI | `EnvironmentValues.imageLoader` and `.speciesContentProvider` keys. Defaults are "unavailable" stubs that fail loudly in debug, never a network client |
| 2 | `Services/CachingContentProvider.swift` | Service (adapter) | `actor CachingContentProvider: SpeciesContentProvider` decorator: memory cache, disk cache (one JSON file per species in an injected directory), and one shared in-flight task per species so feed, onboarding and detail never fetch the same species twice |
| 2 | `Services/ContentCachePolicy.swift` | Service (pure) | `enum ContentCachePolicy`: freshness (7-day TTL), "use stale when offline", file name for a wiki title, entry schema version. Unit-tested |
| 2 | `Services/SpeciesContent.swift` | Service | `WikipediaContentProvider` loses its own `cache` dictionary and `static let shared`; it only fetches |
| 3 | `Features/Feed/FeedViewModel.swift` | Feature | Keep up to two species loads in flight, prefetch images for the next 3 cards on `cardAppeared`, and log time-to-first-card with `os.Logger` signposts |
| 3 | `Services/WikiClient.swift` | Service | Request Wikimedia's standard thumbnail step (1280 px) instead of 1080 so CDN caches hit |
| 4 | `App/AnimalScrollerApp.swift` | App | Creates the one `URLSession`, `ImagePipeline`, `WikipediaContentProvider` wrapped in `CachingContentProvider`, injects them with `.environment` and passes the provider to `FeedViewModel` |
| 5 | `Stores/PreferencesStore.swift`, `Stores/MetStore.swift`, `Stores/LikesStore.swift` | Stores | File moves only |
| 6 | `Models/FeedCard.swift` | Model | `struct CardPlacement { position, count }` on each payload, a computed `FeedCard.placement`, `FeedCard.placed(_:)`, and a computed `FeedCard.primaryImage` (replaces `FeedView.heroURL`'s switch, used for prefetch) |
| 6 | `Features/Feed/FeedViewModel.swift` | Feature | Stamps placement on each composed set (`FeedComposer` is untouched). `positions` becomes a computed compatibility accessor until W2 switches `FeedView`, then is deleted |

## Data flow

```
App/ ── URLSession(URLCache 512 MB disk) ──► ImagePipeline ──env──► FullBleedImage → RemoteImageModel
   └─ WikipediaContentProvider(WikiClient) ─► CachingContentProvider ─┬─► FeedViewModel (init)
                                              (memory → disk → network) ├─env─► Onboarding / Detail VMs (W3)
FeedViewModel.cardAppeared → next 3 cards' primaryImage.url → ImageLoading.prefetch
```

Content still enters only through `WikipediaContentProvider` → `ContentPolicy`. The disk cache
stores the already-filtered `SpeciesContent`; it is a copy of sourced content, not a new source.

## New contracts

- `protocol ImageLoading: Sendable { func image(for url: URL, maxPixelSize: Int) async throws -> CGImage; func prefetch(_ urls: [URL], maxPixelSize: Int) async }`.
- `SpeciesContentProvider` unchanged.
- Disk cache: `Caches/species-content.v1/<sha256(wikiTitle)>.json`, each file
  `{ "schema": 1, "fetchedAt": <date>, "content": SpeciesContent }`. It lives in `Caches/`, so
  iOS may purge it and nothing breaks. Bump to `.v2` if `SpeciesContent` changes shape; old
  directories are deleted on launch. Documented in data-model.md.
- `CardPlacement` added to `IntroCard`, `FactCard`, `PhotoCard` with a default of 1 of 1.
- Imports: `ImagePipeline` needs `ImageIO` and `CoreGraphics`, `CachingContentProvider` needs
  `CryptoKit` (all system frameworks). **Rule change proposed:** add "ImageIO, CoreGraphics,
  CryptoKit for adapters" to the Services row of the layers table. No third-party dependencies.

## Content rules

No new source. Images and text are byte-for-byte what Wikipedia and Commons served, already
through `ContentPolicy`; downsampling only rescales (no crop or edit beyond what we already do on
screen, allowed under CC BY/BY-SA, D-002). Attribution stays on the models. Cached content
refreshes after 7 days so corrected articles reach the device (D-011). No animal content in Swift.

## Tests

- `ImageSizingTests`: pixel size for portrait/landscape/scale 2 and 3, cache key stability.
- `ContentCachePolicyTests`: fresh vs stale vs offline-stale, file names for titles with `/`,
  spaces and non-ASCII, schema mismatch is a miss.
- `CachingContentProviderTests` with a fake provider and a temp directory: second call is a
  memory hit, relaunch is a disk hit, concurrent calls fetch once, stale + network failure returns
  stale.
- `FeedCardTests` for `placed(_:)`, `placement` and `primaryImage`.
- `ImagePipeline` downsampling tested with a small PNG fixture from the test bundle (generated in
  code, no animal content).

## Accessibility

`FullBleedImage` keeps its caption label, marks the loading placeholder hidden from VoiceOver,
and fades in only when Reduce Motion is off.

## Asks from other streams (accepted)

From W2 (`docs/designs/2026-11-06-feed-feel.md`, PR #13):

1. `FeedViewModel.emptyMessage: String?` becomes `notice: FeedNotice?` with
   `enum FeedNotice { case noMatches, offline }` (in `Features/Feed/FeedViewModel.swift`), so
   `FeedView` can show an offline state with "Try again". Done in the step 3 PR.
2. Once W2's `ShimmerFill` lands in `Features/Components`, `FullBleedImage` uses it for the
   loading phase instead of `ProgressView`. Done in step 1 if #13 has merged by then, otherwise a
   follow-up.
3. W1 tells W2 when `CardPlacement` (step 6) lands.

## Open questions

1. **Step 4 touches two files other streams own.** `FeedView.init` (W2) creates the view model, so
   it must take the provider, and `RootView` (W3) must pass it. I propose W1 changes only those
   init-signature lines in the step 4 PR (so the app keeps compiling) and tells W2 and W3 first.
   `OnboardingView` and `SpeciesDetailView` (W3) keep using `WikipediaContentProvider.shared`
   until W3's step 4 switches them to the environment value; W1 then deletes `.shared` in a
   one-line follow-up. Until then `.shared` is marked `@available(*, deprecated)` and is a second
   instance that shares the same disk cache directory, so nothing is fetched twice across launches.
2. Rule change for system-framework imports in Services (above).

## Answers (architect, PR #14)

1. Approved: W1 changes only the init lines in `FeedView` and `RootView`; `.shared` stays deprecated
   until W3 switches Onboarding and Detail. Cache writes are atomic.
2. Approved, in architecture-rules.md (#10). `ContentCachePolicy` ended up using a pure FNV-1a hash,
   so CryptoKit isn't needed.
3. Step 5 waits for W3's PR A.
