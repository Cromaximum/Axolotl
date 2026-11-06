# AGENTS.md

Start here if you are an AI coding agent (Claude Code, Codex, Cursor, Copilot, or anything else)
working in this repo. More than one person works on this project, and each of them runs their own
agents. These docs are how all of you share context. Read them before you change anything and
keep them true after you change something.

## What this project is

**Animal Scroller** (working title "Animal Instagram") is an iOS app (SwiftUI, iOS 17) that works
like a doom-scroll feed for meeting one specific animal species at a time. Each species opens with
a zoo-information-board style intro card, then a paced mix of photos and "Did you know?" fact
cards. Users filter by the scientific tree of life, with toggles for extinct species. Phase 1
content comes only from Wikipedia and Wikimedia Commons under free licences.

## Read before you work

| If you are about to... | Read |
| --- | --- |
| Do anything at all | [docs/status.md](docs/status.md) (what works, what's broken, who is working on what) |
| Change product behaviour or UX | [docs/product.md](docs/product.md) and [docs/decisions.md](docs/decisions.md) |
| Touch images, text, sources or attribution | [docs/content-and-licensing.md](docs/content-and-licensing.md) (hard rules) |
| Change code structure or add a file | [docs/architecture.md](docs/architecture.md) |
| Change a model, JSON shape or saved preference | [docs/data-model.md](docs/data-model.md) |
| Change colours, fonts or card layout | [docs/design.md](docs/design.md) |
| Plan new features | [docs/roadmap.md](docs/roadmap.md) |
| Open a branch, commit or PR | [docs/contributing.md](docs/contributing.md) |

The full index is [docs/README.md](docs/README.md).

## Non-negotiable rules

These come from decisions the project owner made. Do not change them without a new entry in
[docs/decisions.md](docs/decisions.md) that a human approved.

1. **One specific species per feed item.** Never a broad group ("birds", "big cats").
2. **Only CC0, public domain, CC BY or CC BY-SA content.** No NonCommercial (the app is
   ad-supported), no NoDerivatives (we crop), no fair use, no unknown licences. See
   [docs/content-and-licensing.md](docs/content-and-licensing.md).
3. **Every card shows its attribution** (author, licence, source link).
4. **Zero AI-generated content.** Nothing a user sees about an animal may be written, drawn,
   edited, summarised, paraphrased or translated by AI: no facts, captions, descriptions, names,
   conservation statuses, images, video or audio. Every piece of content is pulled from an open
   source (Wikipedia, Wikimedia Commons, Wikidata, or another source approved in
   [docs/content-and-licensing.md](docs/content-and-licensing.md)) and shown verbatim with its
   attribution. Images come only from the species' own Wikipedia article (Wikipedia bans AI
   images). Agents may write code and docs,
   but never content. See
   [docs/content-and-licensing.md](docs/content-and-licensing.md#zero-ai-generated-content) (D-011).
5. **Real animals, real images.** Artist reconstructions (paleoart) are allowed only for extinct
   species, only human-made and from reputable sources, and always labelled "Artist
   reconstruction". Living species only ever show photographs.
6. **Do not commit secrets, API keys or personal contact details.**
7. **Do not push to `main`.** All changes go through pull requests (see
   [docs/contributing.md](docs/contributing.md)).

## Keeping the docs current (required for every change)

The docs are only useful if they match the code. Treat a doc update as part of the change, not
a follow-up. **A PR that changes behaviour without updating the relevant docs is incomplete.**

In the same PR as your code change:

1. **Always** add a line to [docs/changelog.md](docs/changelog.md) under `Unreleased`.
2. **Always** update [docs/status.md](docs/status.md) if you changed what works, what's broken,
   what's in flight, or the species count. Add yourself to "In flight" when you start a
   multi-step piece of work, and remove the row when it merges.
3. Update [docs/architecture.md](docs/architecture.md) if you add, move, rename or delete a source
   file, or change how pieces talk to each other.
4. Update [docs/data-model.md](docs/data-model.md) if you change any `Codable` type, the shape of
   `taxonomy.json`, or the `UserDefaults` preferences format (bump the key version if old data
   would no longer decode).
5. Update [docs/product.md](docs/product.md) if user-visible behaviour changes.
6. Add an entry to [docs/decisions.md](docs/decisions.md) for any product, licensing, design or
   architecture choice that someone could reasonably have made differently. Record who decided
   it. Agents may propose decisions, but mark them `Proposed` until a human confirms.
7. Update [docs/roadmap.md](docs/roadmap.md) when an item is finished, added or dropped.
8. Keep `README.md` (the human-facing quick start) in step if setup steps change.

If you find a doc that is wrong, fix it in your PR even if you didn't cause the drift, and note it
in the changelog. If you are unsure whether something belongs in the docs, put it in.

Before you finish, re-read the "Before you open a PR" checklist in
[docs/contributing.md](docs/contributing.md). The PR template repeats it.

## Quick facts

- Build: `xcodegen generate`, then open `AnimalScroller.xcodeproj` in Xcode 15+ (macOS only).
- Tests: `xcodebuild test -scheme AnimalScroller -destination 'platform=iOS Simulator,name=iPhone 15'`.
- Species data: `AnimalScroller/Resources/taxonomy.json`, generated by `tools/gen_taxonomy.py`.
  Edit the script, then regenerate. Do not hand-edit the JSON.
- `AnimalScroller.xcodeproj` is generated and git-ignored. Change `project.yml`, not the project.
