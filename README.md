# Animal Scroller (working title: Animal Instagram)

> **AI agents:** start with [AGENTS.md](AGENTS.md). Project docs live in [docs/](docs/README.md),
> and every change must keep them up to date.

An iOS doom-scroll feed for meeting specific animal species. Each species opens with a
zoo-information-board style intro card, followed by 3 to 8 photos and "Did you know?" facts
(never two facts in a row), then the feed moves on to the next species.

Phase 1 content comes only from Wikipedia text and Wikimedia Commons images under
CC0, public domain, CC BY or CC BY-SA. NonCommercial and NoDerivatives licences are
rejected because the app will be ad-supported. Every card carries an attribution chip
(author, licence, source link).

## Run it

Requirements: macOS with Xcode 15+, iOS 17 simulator or device, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open AnimalScroller.xcodeproj
```

Then press Run. Tests: `Cmd+U`, or
`xcodebuild test -scheme AnimalScroller -destination 'platform=iOS Simulator,name=iPhone 15'`.

Optional fonts from the design deck: drop `Fredoka-SemiBold.ttf`, `NunitoSans-Regular.ttf`
and `NunitoSans-Bold.ttf` (both OFL, from Google Fonts) into `AnimalScroller/Resources/Fonts/`
and add them under `UIAppFonts` in `project.yml`. Without them the app uses the system font.

## How it fits together

| Piece | File | What it does |
| --- | --- | --- |
| Tree of life | `Resources/taxonomy.json`, `Models/Taxon.swift` | Kingdom › phylum › class › order › family › species. Only species reach the feed. |
| Filters | `Features/Picker/` | Pick any branches, toggle extinct species (include / only), reconstructions, and surprise picks. Saved in UserDefaults. |
| Next species | `Services/SpeciesPicker.swift` | About 70% tailored to your branches, weighted by how long you linger on related families; about 30% random discovery from elsewhere. Strongly favours species you haven't seen and never repeats within the last 12. |
| Content | `Services/WikiClient.swift`, `SpeciesContent.swift` | Wikipedia summary, plain-text article, and the article's Commons images with licence metadata. Sits behind `SpeciesContentProvider`, so prebuilt static JSON per species can replace live fetching later. |
| Rules | `Services/ContentPolicy.swift` | Licence allowlist, junk-image filter (maps, icons, stamps), artwork detection. |
| Facts | `Services/FactExtractor.swift` | Pulls short standalone sentences from sections like Description, Diet and Behaviour. |
| Species set | `Services/FeedComposer.swift` | Intro card, then photo / fact / photo... |
| UI | `Features/Feed/` | Paging vertical feed, zoo-sign intro card with IUCN status bar, fact boards, full-bleed photos, credit sheets. |

### Extinct species and reconstructions

Paleoart is only shown for extinct species, only if it is already used on that species'
English Wikipedia article (where palaeontology editors review reconstructions for accuracy),
and it is always tagged "Artist reconstruction". Living species only ever show photos.

## Seed data

`taxonomy.json` holds 1,090 hand-picked species (55 extinct) across 33 classes, from big cats to
sponges. The species are listed in `tools/species.txt`; `tools/gen_taxonomy.py` pulls their
names, statuses and place in the tree from Wikidata and Wikipedia (D-011: nothing hand-typed). Every entry must be a single species or
subspecies on Wikidata (the script refuses genus articles such as Smilodon). Screen new
titles with `python3 tools/gen_taxonomy.py --screen candidates.txt` first, and run
`python3 tools/gen_taxonomy.py --lint` (offline, also in CI) after editing the list.

## Known gaps / next steps

- Grow the list to a few hundred reviewed species (ideally generated from Wikidata, then reviewed).
- Move content to a prebuilt static JSON pipeline so the app doesn't depend on live Wikipedia calls.
- Replace the contact URL in the `User-Agent` (`WikiClient.swift`) with a real support address.
- App name: "Instagram" is a Meta trademark, so the shipping name must change.
- Ads SDK, App Store assets, privacy manifest.

## Continuous integration

`.github/workflows/ios.yml` runs on every pull request and push to `main`: it installs
XcodeGen on a macOS runner, generates the project, then builds and runs the unit tests on
an iPhone simulator. Test results and the build log are uploaded as a workflow artifact.
