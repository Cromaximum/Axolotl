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

## D-017 · The intro card is a short fact sheet, from Wikidata with a Wikipedia-sentence fallback
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Maxwell: "the first screen should really be a fact sheet with core details and
  attributes about the animal without being overwhelming or verbose ... ie, diet, range, size".
  Wikidata covers range for about 45% of bundled species, weight 22%, size 15%, diet 13%.
- Decision: The intro board shows up to four rows (Lives in, Eats, size, Weight), only with
  sourced data. Wikidata values first; where Wikidata has none, one whole sentence of at most
  90 characters from the article's matching section (Maxwell chose this option on 2026-11-06).
  With no data at all the intro falls back to "Did you know?" / the lead.
- Consequences: New `SpeciesProfile` on `SpeciesContent` (cache schema v2), `WikidataClient`,
  pure `SpeciesProfileBuilder`. Fact sets are also capped at 4 cards after the intro, never
  repeat an image, and highlight a fact's number inside its sentence instead of showing it alone
  (same feedback round).

## D-016 · Architecture review gate suspended
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Maxwell: "remove the architect role for now, have bots just proceed with best
  intentions".
- Decision: D-014's design-note-and-sign-off gate is paused. Agents proceed on their best
  judgment and merge their own PRs once CI is green. The rules in architecture-rules.md
  (layers, no hard-coded animal content, tests) still apply, as do zero AI content (D-011) and
  keeping the docs current.
- Consequences: Design notes in `docs/designs/` are still welcome for bigger changes but don't
  block. Supersedes the gate part of D-014 until Maxwell turns it back on.

## D-015 · Subspecies count as one specific animal
- Status: Proposed (agent, W4 content quality, 2026-11-06)
- Date: 2026-11-06
- Decided by: pending (Maxwell Rhinelander)
- Context: `gen_taxonomy.py` now refuses any listed title whose Wikidata item is not a species
  (AGENTS.md rule 1). A few famous animals are subspecies on Wikidata, for example the Pinta
  Island tortoise (Lonesome George's kind).
- Decision: Accept Wikidata rank species or subspecies. A subspecies is narrower than a species,
  so it is still one specific animal, never a broad group. Genus articles (Smilodon,
  Tyrannosaurus, Tuatara) are refused and were removed from the bundled list.
- Consequences: Rule 1 is checked by the build. Popular genus-level fossils only appear if
  Wikipedia has a species article for them.

## D-014 · Architecture review gate: design before code, sign-off before merge
- Status: Decided; gate suspended by D-016 (2026-11-06)
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: Several people's AI agents write code in this repo. Maxwell asked for "a bot that functions as the programming architect" so that new code is confirmed to fit the program's architecture before it starts and before it reaches `main`, "to avoid any long term AI spaghetti code difficulties".
- Decision: A Claude architect agent owns [architecture-rules.md](architecture-rules.md). Every piece of work bigger than a one-file fix posts a design note (draft PR with `docs/designs/...`) and waits for `Architecture review: Design approved`. Every PR needs `Architecture review: Approved` on its latest commit before it merges. The architect then merges it once CI is green (Maxwell approved architect merges on 2026-11-06). Applies to collaborators' agents too. Maxwell can sign off if the architect hasn't answered in 24 hours.
- Consequences: Work starts a little slower, but layers and dependency rules are enforced on every change. Because all agents post through one GitHub account, sign-off is a marker comment, not a GitHub approval, so branch protection can't enforce it; the architect only merges what it signed off. The layer model (proposed by the architect agent) moves app-wide stores into `Stores/` and forbids hard-coded animal content in Swift.

## D-013 · Likes steer the tailored picks
- Status: Decided (feature); weights Proposed
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander asked for "a like feature that drives what content the user sees". Weights proposed by the live catalog agent.
- Context: Dwell time alone is a weak, invisible signal.
- Decision: A heart on every card (and double-tap anywhere) likes a species. Likes are stored separately from saves (`likes.v1`). Each like adds interest to the species' genus (2.5), family (2.0), order (1.0) and class (0.4). That interest is added to dwell-time affinity for tailored picks of bundled species, for choosing which branch the live catalogue searches, and for choosing among live candidates. Interest is capped (6) so the feed never collapses onto one family. Discovery picks ignore likes, so the ~30% surprise share of D-001 is unchanged. Novelty still wins: liked species themselves aren't repeated more, their relatives are.
- Consequences: Likes persist across launches; dwell affinity still resets on launch.

## D-012 · Live species catalogue from the GBIF Backbone Taxonomy
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander asked for the live master species list and confirmed that "all species may skip human review". GBIF as the source and the automatic quality gates were proposed by the live catalog agent.
- Context: Maxwell asked for "an algorithm pulling from a reputable master species list, then search and populate cards as the user goes". Options were Catalogue of Life (ChecklistBank API), the GBIF Backbone (built on CoL plus other expert checklists) and Wikidata's taxonomy.
- Decision: Use the GBIF Backbone. It has one clean kingdom › … › genus classification per accepted species, a fast keyless search API with "species under this taxon" and an extinct filter, and CC BY 4.0. CoL is authoritative but its API is slower and less suited to random sampling; Wikidata's parent-taxon tree is inconsistent and its SPARQL endpoint times out on large subtrees. For each load the app picks a branch of the bundled tree (weighted by likes and dwell), pulls a random page of ~40 accepted species from GBIF, checks all 40 against English Wikipedia in one request, keeps species with a real article (≥ 5,000 bytes, free lead image, not a redirect to a group), picks one favouring unseen and better-covered species, and builds its cards from Wikipedia and Commons as before. While bundled species in scope are unseen, about half of picks are live; after that, all are. Users can turn it off ("Explore the full species catalogue").
- Status display (Maxwell, 2026-11-06: "do not add extinct unless it is abundantly obvious or clearly stated, rather just say unknown or omit it entirely"): a live species shows an IUCN status only from Wikidata P141, and Extinct only when Wikidata says EX or GBIF flags it extinct. With no sourced value the IUCN bar is left out and the status reads "Unknown". Wikipedia short-description keywords ("extinct", "fossil") are used only to keep fossils out of "Living only", never displayed.
- Consequences: Supersedes the "each reviewed" part of D-006: live species are checked automatically, not by a person. Adds `api.gbif.org` and `www.wikidata.org` to the hosts the app calls. Live species only reach branches present in the bundled tree, so growing the tree widens the catalogue.

## D-011 · Zero AI-generated content
- Status: Decided
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: The app is for education, so everything in it must be real and traceable. Maxwell: "zero AI generated content, words, pictures, anything. All content is pulled from open source, creative commons, whatever."
- Decision: No AI-generated, AI-rewritten or AI-edited text, images, audio or video in the app. All content comes verbatim from open sources (Wikipedia, Commons, Wikidata, or other approved free sources) with attribution. Images come only from the species' English Wikipedia article, where AI images are not allowed, so no separate AI-image filter is needed (Maxwell, 2026-11-06). Agents may write code and docs but never content.
- Consequences: Hand-typed species data (common names, group names, IUCN statuses) must be regenerated from Wikidata; mockup text should be verbatim. See [ai-content-audit.md](ai-content-audit.md). Strengthens D-005 (paleoart must be human-made).

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
- Status: Decided; "each reviewed" superseded by D-012 (all species may skip human review)
- Date: 2026-11-06
- Decided by: Maxwell Rhinelander
- Context: How big the species set must be before launch.
- Decision: A few hundred species, each reviewed. Currently 361 (W4, 2026-11-06).
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
