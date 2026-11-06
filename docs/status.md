# Current status

_Last updated: 2026-11-06. Update this file whenever what works, what's broken or what's in
flight changes._

## Summary

First version of the app is on `main`. It compiles and all 11 unit tests pass in CI
(macOS runner, iPhone simulator, first run 2026-11-06). It has **not yet been run by hand** in a
simulator or on a device, so screens and live Wikipedia loading are unverified.

| Area | State |
| --- | --- |
| Build | Compiles cleanly in CI (Xcode on macos-15) |
| Unit tests | 17 tests in `AnimalScrollerTests/`, all passing in CI |
| CI | `.github/workflows/ios.yml`: XcodeGen + `xcodebuild test` on macos-15 for every PR and push to `main`. Results bundle and log uploaded as an artifact. |
| Feed (intro, photo and fact cards) | Code complete, unverified on device |
| Tree-of-life filter + extinct toggles | Code complete, unverified on device |
| Live Wikipedia / Commons fetching | Code complete, unverified. The cloud dev environment can reach `en.wikipedia.org`, `commons.wikimedia.org` and `upload.wikimedia.org` since 2026-11-06 (not `thumb.wikimedia.org`) |
| Species data | 77 species (20 extinct) in `taxonomy.json`. Launch target is a few hundred. |
| IUCN statuses | Filled in by hand, must be checked against the Red List before launch |
| Fonts (Fredoka, Nunito Sans) | Not bundled. App falls back to the system font. |
| Concept screens | Twelve screens in `docs/design/` (D-010). App views rebuilt to match in `feature/concept-screens` (see In flight); not yet checked on a simulator. |
| App name | Working title only. Must change before App Store (trademark). |
| Ads, privacy manifest, App Store assets | Not started |

## In flight

Add a row when you start multi-step work so other agents don't collide with you. Remove it when
the PR merges or is abandoned.

| Work | Who / where | Branch or PR | Started |
| --- | --- | --- | --- |
| Rebuild screens to the concept art (D-010) | Maxwell's agents (iOS programmer thread) | `feature/concept-screens` | 2026-11-06 |

## Known issues

- The app has not been run by hand yet. CI proves it builds and the logic tests pass, not that the screens look right.
- `WikiClient.userAgent` has a placeholder contact URL. Wikimedia requires a real contact
  before release.
- Content is fetched live from Wikipedia on device. The plan is a prebuilt static JSON pipeline
  (see [roadmap.md](roadmap.md)).
- Artwork detection (`ContentPolicy.isArtwork`) is keyword-based and will misclassify some files.
