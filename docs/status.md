# Current status

_Last updated: 2026-11-06. Update this file whenever what works, what's broken or what's in
flight changes._

## Summary

First version of the app is on `main`. It was first compiled and run by hand on 2026-11-06
(Xcode 26.6, iPhone 17 simulator, iOS 26): it builds without errors, all unit tests pass after a
test-target fix, and the feed loads live Wikipedia content. CI also builds and tests every PR.

| Area | State |
| --- | --- |
| Build | Builds clean with Xcode 26.6 locally and in CI (macos-15) |
| Unit tests | 17 tests in `AnimalScrollerTests/`, all passing in CI (11 were also run on the simulator before the concept-screen rebuild) |
| CI | `.github/workflows/ios.yml`: XcodeGen + `xcodebuild test` on macos-15 (first available iPhone simulator) for every PR and push to `main`. Results bundle and log uploaded as an artifact. |
| Feed (intro, photo and fact cards) | The original cards worked in the iPhone 17 simulator. The cards rebuilt to the concept art (`feature/concept-screens`) pass CI but have not been checked by hand yet |
| Tree-of-life filter + extinct toggles | Now the Tree tab. The earlier sheet version listed the tree in the simulator; filtering not yet tested by hand |
| Live Wikipedia / Commons fetching | Works in the simulator. The cloud dev environment can reach `en.wikipedia.org`, `commons.wikimedia.org` and `upload.wikimedia.org` since 2026-11-06 (not `thumb.wikimedia.org`) |
| Species data | 77 bundled species (20 extinct) in `taxonomy.json`. Launch target is a few hundred. |
| Live species catalogue (D-012) | Merged (#7), unit-tested in CI only. Not yet run against the live GBIF API: the cloud dev environment and the Mac VM can't reach `api.gbif.org` or `www.wikidata.org`. Needs a simulator check |
| Likes (D-013) | Merged (#7), unit-tested in CI only; needs a simulator check |
| IUCN statuses, common names, group names | Generated from Wikidata and Wikipedia (D-011, #9). 9 species have no IUCN status in either source and show NE |
| Fonts (Fredoka, Nunito Sans) | Not bundled. App falls back to the system font. |
| Concept screens | Twelve screens in `docs/design/` (D-010). App views rebuilt to match (#4); layout still needs a hand check on a simulator. |
| Architecture review gate | Rules in [architecture-rules.md](architecture-rules.md) (D-014). Every design and PR needs architect sign-off. |
| App name | Working title only. Must change before App Store (trademark). |
| Ads, privacy manifest, App Store assets | Not started |

## In flight

Add a row when you start multi-step work so other agents don't collide with you. Remove it when
the PR merges or is abandoned.

| Work | Who / where | Branch or PR | Started |
| --- | --- | --- | --- |
| W3: Tree search, Met filters and sort, slim Met saves (`met.v2`), onboarding and detail view models | Claude, thread "Improve onboarding, tree and saves" | `claude/project-thread-i5urhz` (design review) | 2026-11-06 |

## Known issues

- Only tested in the simulator so far, not on a physical iPhone.
- App-wide stores (`PreferencesStore`, and `MetStore` from PR #4) live under `Features/` instead of `Stores/`. One small move PR after #4 merges (see [architecture-rules.md](architecture-rules.md#layers)).
- Bundled species data and mockup text were written by AI and must be replaced with sourced
  values (D-011). Full list in [ai-content-audit.md](ai-content-audit.md).
- `WikiClient.userAgent` has a placeholder contact URL. Wikimedia requires a real contact
  before release.
- Content is fetched live from Wikipedia on device. The plan is a prebuilt static JSON pipeline
  (see [roadmap.md](roadmap.md)).
- Artwork detection (`ContentPolicy.isArtwork`) is keyword-based and will misclassify some files.
  It now includes Spanish, French, German, Italian and Portuguese stems, but other languages or
  undescribed files can still slip through unlabelled.
