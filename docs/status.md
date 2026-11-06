# Current status

_Last updated: 2026-11-06. Update this file whenever what works, what's broken or what's in
flight changes._

## Summary

First version of the app is on `main` (one commit, 2026-11-06). **It has never been compiled.**
It was written in an environment without Xcode, so expect build errors on first compile. CI and
build fixes are in progress (see "In flight").

| Area | State |
| --- | --- |
| Build | Not yet compiled. Unknown. |
| Unit tests | Written (`AnimalScrollerTests/`), never run |
| CI | Being added in PR #1 (`ci/macos-build`): XcodeGen + `xcodebuild test` on macos-15 for every PR |
| Feed (intro, photo and fact cards) | Code complete, unverified on device |
| Tree-of-life filter + extinct toggles | Code complete, unverified on device |
| Live Wikipedia / Commons fetching | Code complete, unverified. The cloud dev environment can reach `en.wikipedia.org`, `commons.wikimedia.org` and `upload.wikimedia.org` since 2026-11-06 (not `thumb.wikimedia.org`) |
| Species data | 77 species (20 extinct) in `taxonomy.json`. Launch target is a few hundred. |
| IUCN statuses, common names, group names | **Typed in by an AI agent, which breaks D-011 (zero AI content).** Must be regenerated from Wikidata. See [ai-content-audit.md](ai-content-audit.md) |
| AI-image filter | Missing: `ContentPolicy` doesn't yet reject AI-generated Commons files |
| Fonts (Fredoka, Nunito Sans) | Not bundled. App falls back to the system font. |
| Concept screens | Twelve screens in `docs/design/` (D-010). App views not yet updated to match. |
| App name | Working title only. Must change before App Store (trademark). |
| Ads, privacy manifest, App Store assets | Not started |

## In flight

Add a row when you start multi-step work so other agents don't collide with you. Remove it when
the PR merges or is abandoned.

| Work | Who / where | Branch or PR | Started |
| --- | --- | --- | --- |
| GitHub Actions CI for iOS build and tests | Maxwell's agents | PR #1, `ci/macos-build` | 2026-11-06 |
| Fix first-compile build errors on a Mac | Maxwell's agents | TBD | 2026-11-06 |
| Zero-AI-content rule and audit (D-011) | Maxwell's agents | `claude/project-thread-g3dioe` | 2026-11-06 |

## Known issues

- Bundled species data and mockup text were written by AI and must be replaced with sourced
  values (D-011). Full list in [ai-content-audit.md](ai-content-audit.md).
- Code has not been compiled or run. Treat every "complete" above as untested.
- `WikiClient.userAgent` has a placeholder contact URL. Wikimedia requires a real contact
  before release.
- Content is fetched live from Wikipedia on device. The plan is a prebuilt static JSON pipeline
  (see [roadmap.md](roadmap.md)).
- Artwork detection (`ContentPolicy.isArtwork`) is keyword-based and will misclassify some files.
