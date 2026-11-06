# Product requirements

What the app must do and why. Decisions behind these are in [decisions.md](decisions.md).

## Goal

Education and discovery: introduce people to animal species they've never heard of, in the
format of an endless vertical feed. Every item is about **one specific species**.

## Users see

### First run

1. **Welcome**: one full-bleed photo (a shoebill), "Meet a new species every swipe.", a
   "Start exploring" button.
2. **Where should we start?**: photo tiles for Mammals, Birds, Reptiles, Amphibians, Insects,
   Crustaceans, Fossil life and Surprise me. Picking tiles selects those tree branches; "Fossil
   life" alone switches to extinct-only; picking nothing means the whole kingdom. Surprise picks
   stay on either way. Shown once (`hasOnboarded`).

### Tabs

**Feed**, **Tree** (the tree-of-life filters) and **Met** (the species collection).

### The feed

- A full-screen, vertically paging feed (one card per screen) that draws under the status bar.
- Layout rule (D-010): the animal gets the frame. Photos run edge to edge; text only sits in the
  bottom zoo-board panel or on a lower-third scrim; chips hug the top and bottom edges. Tall
  photos are top-anchored so the head stays high; wide photos are shown whole over a blurred copy.
- Content comes in **species sets**. Each set is:
  1. **Intro card**: the hero photo full-bleed, with a zoo-board sign at the bottom: common name,
     scientific name, taxonomic path, a "Did you know?" box (or the lead if there are no facts),
     and the IUCN status bar (LC › NT › VU › EN › CR › EW › EX). Progress dashes and the photo
     credit sit at the top. Tapping the sign opens the species detail sheet.
  2. Then **3 to 8 items**, alternating photos and fact cards. Two fact cards never sit next to
     each other. Leftover photos may run together at the end; leftover facts are dropped.
     - **Photo card**: animal only, with a "Name · n of N" pill, a credit chip and a Like / Save /
       Info / Share rail. Extinct species add a media tag and a caption on the scrim.
     - **Fact card**: a photo of the species on the top half, and a board below with "Did you
       know? · Topic", the fact's stand-out number in large type (years are skipped), the
       sentence, and the source line.
- Extinct-species media is tagged **Historical photo**, **Real fossil** or amber
  **Reconstruction in frame**. Living species are never tagged (they only show photos).
- Then the next species. The feed prefetches so it never runs dry (keeps about 6 cards queued).
- Every card has an attribution chip; tapping it opens a credit sheet (author, licence, source).
- **Save** a species with the bookmark on the rail or by long-pressing any card.
- **Like** a species with the heart (on the photo rail, the intro card's top row and the fact
  card's top row) or by double-tapping any card, which pops an amber heart. Double-tap only
  likes; tap the heart again to unlike. Likes steer the feed (see below) and persist.

### Species detail sheet

Opened from ⓘ, the intro sign, a fact's source line, or a collection tile: hero photo with
credit, names, full lineage, quick-fact tiles (status, class, order, family, short
description), "Did you know?", the lead, more facts, and every source and credit.

### Species met

Every species whose intro card was shown is added automatically (newest first). Filters: All /
Saved / Extinct. Tap a tile for the detail sheet. Persisted across launches.

### Choosing the next species

- About **70% tailored**: from the tree-of-life branches the user picked, weighted towards
  families, orders and classes they linger on (dwell time, capped at 60 seconds per species).
- About **30% discovery**: random species from outside the user's branches ("Surprise me").
  Turning Surprise off makes it 100% tailored.
- **Likes** (D-013) add interest to the liked species' genus, family, order and class, on top of
  dwell time. Tailored picks then favour its relatives; the liked species itself isn't repeated
  more. Discovery picks ignore likes.
- Strongly favours species the user hasn't seen. Never repeats a species within the last 12.
- **Full species catalogue** (D-012, default on): besides the bundled hand-picked list, the feed
  finds species from the GBIF Backbone Taxonomy under the same branches (and, for discovery
  picks, outside them), keeping only species with a substantial, illustrated English Wikipedia
  article. About half of picks are live while bundled species in scope are unseen; all are
  live after that. Live species show their Wikipedia article title as the common name and
  their Wikidata IUCN status (Not Evaluated if none). Their detail sheet credits GBIF.
- If nothing is selected, the whole animal kingdom is in scope.

### Filters (tree-of-life picker)

- Browsable outline: kingdom › phylum › class › order › family (species are leaves under a
  family or genus but are not individually selectable in Phase 1).
- Selecting a node selects its whole subtree. Selecting a parent folds away redundant child
  selections. Rows show species counts.
- A three-way switch: **Living only / Include extinct** (default) **/ Extinct only**.
- Toggles:
  - **Show artist reconstructions** (default on; only affects extinct species; hidden when
    Living only)
  - **Surprise picks** (default on)
  - **Explore the full species catalogue** (default on)
- Preferences persist across launches.

### Extinct species

- Shown with fossils, specimens and photos, plus labelled reconstructions when allowed.
- See [content-and-licensing.md](content-and-licensing.md#paleoart-and-reconstructions).

## Constraints

- iOS 17+, iPhone, portrait only, dark appearance.
- No account or login in Phase 1.
- Ad-supported (ads SDK not integrated yet).
- English only for now.

## Out of scope for Phase 1

Video, sounds, accounts, social sharing beyond the system share sheet, quizzes, partner footage. See
[roadmap.md](roadmap.md).
