# Current status

_Last updated: 2026-11-07. Update this file whenever what works, what's broken or what's in
flight changes._

## Summary

First version of the app is on `main`. It was first compiled and run by hand on 2026-11-06
(Xcode 26.6, iPhone 17 simulator, iOS 26): it builds without errors, all unit tests pass after a
test-target fix, and the feed loads live Wikipedia content. CI also builds and tests every PR.

| Area | State |
| --- | --- |
| Build | Builds clean with Xcode 26.6 locally and in CI (macos-15) |
| Unit tests | 150 tests in `AnimalScrollerTests/` (counted 2026-11-07, including `FeedNavigationTests`), run in CI on every PR |
| CI | `.github/workflows/ios.yml`: XcodeGen + `xcodebuild test` on macos-15 (first available iPhone simulator) for every PR and push to `main`. Results bundle and log uploaded as an artifact. |
| Feed (intro, photo and fact cards) | The original cards worked in the iPhone 17 simulator. The cards rebuilt to the concept art (`feature/concept-screens`) pass CI but have not been checked by hand yet |
| Intro fact sheet (D-017) | Lives in / Eats / size / Weight from Wikidata, short Wikipedia sentence fallback (#20). Unit-tested in CI only; needs a simulator check. The cloud dev environment is rate-limited by Wikidata |
| Core feed UX round (D-021) | Next-animal chip, "New to you" badge, pinch zoom on photo cards, first-run swipe hint. Unit-tested in CI only (`FeedNavigationTests`); needs a simulator check |
| Tree-of-life filter + extinct toggles | Now the Tree tab, with search, species counts per branch, a "Showing" summary and "Reset to everything" (W3, #11; CI only, not yet checked by hand). The earlier sheet version listed the tree in the simulator |
| Photo selection | Photos ranked best first by `PhotoQuality` (Commons assessments, resolution, portrait fit, close-ups), soft originals dropped when a species has 2+ sharp ones, 1920 px or 3840 px renditions (2026-11-06). CI only, not yet checked by hand in the simulator |
| Live Wikipedia / Commons fetching | Works in the simulator. The cloud dev environment can reach `en.wikipedia.org`, `commons.wikimedia.org` and `upload.wikimedia.org` since 2026-11-06 (not `thumb.wikimedia.org`) |
| Species data | 1,466 bundled species (55 extinct) in `taxonomy.json`, across 10 phyla, 34 classes, 194 orders and 576 families (roster expansion: 361 → 1,090 on 2026-11-06, → 1,466 on 2026-11-07). By class: mammals 327, birds 254, insects 205, other reptiles 191, ray-finned fish 126, amphibians 84, crustaceans 45, sharks and rays 42, arachnids 37, gastropods 36. Every entry is a Wikidata species or subspecies; the 1,105 added since 2026-11-06 also passed `gen_taxonomy.py --screen` (article of 12,000+ bytes, free lead image, 3+ sharp photos under the app's photo rules). `gen_taxonomy.py --lint` checks the files in CI. Invertebrate phyla other than arthropods and molluscs have few species because few of their Wikipedia articles pass the screen. |
| Live species catalogue (D-012) | Merged (#7), unit-tested in CI only. Not yet run against the live GBIF API: the cloud dev environment and the Mac VM can't reach `api.gbif.org` or `www.wikidata.org`. Needs a simulator check |
| Likes (D-013) | Merged (#7), unit-tested in CI only; needs a simulator check |
| Achievements (D-016) | Awards tab, tier banner and tab badge. Unit-tested in CI only; needs a simulator check |
| IUCN statuses, common names, group names | Generated from Wikidata and Wikipedia (D-011, #9). 297 of 1,466 species have no IUCN status in either source and show NE (mostly invertebrates and fossils the IUCN never assessed) |
| Fonts (Fredoka, Nunito Sans) | Bundled (latin subsets, OFL) in `Resources/Fonts/`; `ThemeFontTests` checks they load. Scientific names use the system italic. |
| Concept screens | Twelve screens in `docs/design/` (D-010). App views rebuilt to match (#4); layout still needs a hand check on a simulator. |
| Architecture review gate | Suspended 2026-11-06 (D-014). Rules in [architecture-rules.md](architecture-rules.md) still apply; PR authors merge once CI is green. |
| App name | Working title only. Must change before App Store (trademark). |
| Ads, privacy manifest, App Store assets | Not started |

## In flight

Add a row when you start multi-step work so other agents don't collide with you. Remove it when
the PR merges or is abandoned.

| Work | Who / where | Branch or PR | Started |
| --- | --- | --- | --- |
| W1 step 5: move the stores to `Stores/`. Then delete `WikipediaContentProvider.shared` after W3 PR B | Claude, thread "Speed up feed loading and caching" | `claude/project-thread-72fg80` (steps 0 to 4 and 6 merged in #14) | 2026-11-06 |
| W3: Tree search, Met filters and sort, slim Met saves (`met.v2`), onboarding and detail view models | Claude, thread "Improve onboarding, tree and saves" | PR A #11 merged; PR B #19 (onboarding, detail and Met grid on the injected provider and image loader) | 2026-11-06 |
| Polish and performance workstreams W1 to W4 ([roadmap](roadmap.md#phase-15-polish-and-performance-current-from-2026-11-06)) | One thread per workstream | see roadmap | 2026-11-06 |

## Known issues

- Only tested in the simulator so far, not on a physical iPhone.
- Bundled species data and mockup text were written by AI and must be replaced with sourced
  values (D-011). Full list in [ai-content-audit.md](ai-content-audit.md).
- `WikiClient.userAgent` has a placeholder contact URL. Wikimedia requires a real contact
  before release.
- Content is fetched live from Wikipedia on device. The plan is a prebuilt static JSON pipeline
  (see [roadmap.md](roadmap.md)).
- Artwork detection (`ContentPolicy.isArtwork`) is keyword-based and will misclassify some files.
  It now includes Spanish, French, German, Italian and Portuguese stems, but other languages or
  undescribed files can still slip through unlabelled.
