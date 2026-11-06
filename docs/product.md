# Product requirements

What the app must do and why. Decisions behind these are in [decisions.md](decisions.md).

## Goal

Education and discovery: introduce people to animal species they've never heard of, in the
format of an endless vertical feed. Every item is about **one specific species**.

## Users see

### The feed

- A full-screen, vertically paging feed (one card per screen).
- Content comes in **species sets**. Each set is:
  1. **Intro card**: a zoo-information-board style sign with the hero photo, common name,
     scientific name, taxonomic path, a one-to-two sentence lead, a "Did you know?" box, and the
     IUCN conservation status scale (LC › NT › VU › EN › CR › EW › EX).
  2. Then **3 to 8 items**, alternating photos and fact cards. Two fact cards never sit next to
     each other. Leftover photos may run together at the end; leftover facts are dropped.
- Then the next species. The feed prefetches so it never runs dry (keeps about 6 cards queued).
- Every card has an attribution chip; tapping it opens a credit sheet (author, licence, source).

### Choosing the next species

- About **70% tailored**: from the tree-of-life branches the user picked, weighted towards
  families, orders and classes they linger on (dwell time, capped at 60 seconds per species).
- About **30% discovery**: random species from outside the user's branches ("Surprise me").
  Turning Surprise off makes it 100% tailored.
- Strongly favours species the user hasn't seen. Never repeats a species within the last 12.
- If nothing is selected, the whole animal kingdom is in scope.

### Filters (tree-of-life picker)

- Browsable outline: kingdom › phylum › class › order › family (species are leaves under a
  family or genus but are not individually selectable in Phase 1).
- Selecting a node selects its whole subtree. Selecting a parent folds away redundant child
  selections. Rows show species counts.
- Toggles:
  - **Include extinct species** (default on)
  - **Extinct species only** (only when extinct is included)
  - **Show artist reconstructions** (default on; only affects extinct species)
  - **Surprise me with other species** (default on)
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

Video, sounds, saves/collections, accounts, sharing, quizzes, partner footage. See
[roadmap.md](roadmap.md).
