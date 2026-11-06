# Decision log

Choices that someone could reasonably have made differently. Newest first. Never delete an entry:
if a decision is reversed, add a new entry and mark the old one `Superseded by D-NNN`.

**Status values:** `Decided` (a human owner confirmed it), `Proposed` (an agent or collaborator
suggested it, waiting for a human), `Superseded`.

Agents: you may add `Proposed` entries. Only change one to `Decided` when a human has said so,
and record who.

Template:

```
## D-NNN · Title
- Status: Proposed | Decided | Superseded by D-NNN
- Date: YYYY-MM-DD
- Decided by: name (or "proposed by <agent/person>")
- Context: why this came up
- Decision: what we do
- Consequences: what this rules in or out
```

---

## D-014 · Architecture review gate: design before code, sign-off before merge
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Several people's AI agents write code in this repo. Maxwell asked for "a bot that functions as the programming architect" so that new code is confirmed to fit the program's architecture before it starts and before it reaches `main`, "to avoid any long term AI spaghetti code difficulties".
- Decision: A Claude architect agent owns [architecture-rules.md](architecture-rules.md). Every piece of work bigger than a one-file fix posts a design note (draft PR with `docs/designs/...`) and waits for `Architecture review: Design approved`. Every PR needs `Architecture review: Approved` on its latest commit before it merges. The architect then merges it once CI is green (Maxwell approved architect merges on 2026-11-06). Applies to collaborators' agents too. Maxwell can sign off if the architect hasn't answered in 24 hours.
- Consequences: Work starts a little slower, but layers and dependency rules are enforced on every change. Because all agents post through one GitHub account, sign-off is a marker comment, not a GitHub approval, so branch protection can't enforce it; the architect only merges what it signed off. The layer model (proposed by the architect agent) moves app-wide stores into `Stores/` and forbids hard-coded animal content in Swift.

## D-011 · Zero AI-generated content
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: The app is for education, so everything in it must be real and traceable. Maxwell: "zero AI generated content, words, pictures, anything. All content is pulled from open source, creative commons, whatever."
- Decision: No AI-generated, AI-rewritten or AI-edited text, images, audio or video in the app. All content comes verbatim from open sources (Wikipedia, Commons, Wikidata, or other approved free sources) with attribution. AI-generated files on Commons are rejected. Agents may write code and docs but never content.
- Consequences: Hand-typed species data (common names, group names, IUCN statuses) must be regenerated from Wikidata; `ContentPolicy` needs an AI-image filter; mockup text should be verbatim. See [ai-content-audit.md](ai-content-audit.md). Strengthens D-005 (paleoart must be human-made).

## D-010 · Species first, information second
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Maxwell asked for full-screen real images with clear, readable text that doesn't obscure the frame: "the focus on the species, then the brain seeks out the information".
- Decision: Edge-to-edge photos; text only in the bottom zoo-board panel or a lower-third scrim; crops keep the head in the top ~55%; wide photos shown whole over a blurred fill. Concept screens in `docs/design/`.
- Consequences: App views in `Features/` should follow `docs/design/concept-art/`; see [design.md](design.md) rules.

## D-009 · Agent docs live in the repo and are updated with every change
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: A collaborator with their own AI agents also works in this repo. Agents can't see each other's chats.
- Decision: `AGENTS.md` is the entry point; `CLAUDE.md` defers to it; details live in `docs/`. Every PR updates the relevant docs in the same PR.
- Consequences: A PR that changes behaviour without a doc update is incomplete.

## D-008 · All changes after the first commit go through pull requests
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: The first app commit was pushed straight to `main`.
- Decision: From now on, every change is a branch and a PR. CI (PR #1) runs on every PR.
- Consequences: Nobody pushes to `main` directly.

## D-007 · Ad-supported, so only CC0 / public domain / CC BY / CC BY-SA
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Monetisation model decides which Creative Commons licences are usable.
- Decision: The app is free with ads. NonCommercial (NC) is out. NoDerivatives (ND) is out because cards crop images.
- Consequences: See [content-and-licensing.md](content-and-licensing.md). Enforced in `ContentPolicy.isAllowedLicense`.

## D-006 · Launch with a few hundred reviewed species
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: How big the species set must be before launch.
- Decision: A few hundred species, each reviewed. Currently 77.
- Consequences: Needs a generation pipeline (likely Wikidata) plus human review.

## D-005 · Paleoart allowed for extinct species, reputable sources only, always labelled
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Many extinct species have no photographs.
- Decision: Artist reconstructions are allowed from reputable sources (museums, journals, recognised paleoartists). Always labelled "Artist reconstruction". Users can turn them off.
- Consequences: Phase 1 implementation only shows artwork already used on the species' English Wikipedia article (editor-reviewed), never for living species.

## D-004 · Keep "Animal Instagram" as the working title for now
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: "Instagram" is a Meta trademark.
- Decision: Fine internally; the shipping name must change before App Store submission. The bundle display name is already "Animal Scroller".
- Consequences: Don't use "Instagram" in user-facing strings, store listings or bundle ids.

## D-003 · Zoo information boards are the visual language
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Decision: Wood-framed green panels, common + scientific name, "Did you know?" call-outs, IUCN status bar. Palette and fonts in [design.md](design.md).

## D-002 · Filters follow the scientific tree of life, with an extinct toggle
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Decision: Kingdom › phylum › class › order › family › species. Toggles: include extinct, extinct only, show reconstructions, surprise picks.

## D-001 · Feed shows one specific species at a time, about 70% tailored and 30% discovery
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: The goal is education and introducing people to species they don't know.
- Decision: Every feed item is one species, never a broad group. About 70% of picks come from the user's chosen branches (weighted by dwell time), about 30% are random discoveries from elsewhere. The split is tunable.
- Consequences: `SpeciesPicker.discoveryShare = 0.3`; strongly favours unseen species; no repeats within the last 12.
