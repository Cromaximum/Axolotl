# Design: Shorter species sets, no repeated photos, no context-free big numbers, intro fact sheet

- Author: Claude (thread "Expand species variety and fact quality"), from Maxwell Rhinelander's feedback after testing main
- Date: 2026-11-06
- Status: Draft

## Problem

Maxwell tested main and reported two things (2026-11-06):

1. "Pictures are occasionally re-used." Cause: `FeedComposer.factBackdrops` fills each fact
   card's photo from a pool of the hero plus every photo in the set, so a photo already shown on
   the intro or a photo card comes back above a fact board whenever there are fewer spare photos
   than facts.
2. "A lot of the text uses a large attention-grabbing number that only makes sense after
   reading the fact" (a puffin and a big "40"). Cause: `FactCardView` shows
   `FactFormatting.leadingNumber` at 64 pt above the sentence, with nothing next to it.
3. "It lingers far too long on each animal." Cause: `FeedComposer.maxItems = 8`, so a
   well-illustrated species takes up to 9 screens (intro + 8).

## Where it goes

| File | Owner | Change |
| --- | --- | --- |
| `Services/FeedComposer.swift` | W4 | `maxItems` 8 → 4, so a species is at most 5 screens: intro, photo, fact, photo, fact (two facts on cards plus the headline fact on the intro board). Every image appears at most once per species set (hero included). A fact card needs its own unused photo, so the number of fact cards is capped by spare photos: k facts need k backdrops plus k-1 photo cards between them. Remaining photos become photo cards (still max two in a row, max 4 items). `factBackdrops` is removed. |
| `Features/Feed/FactCardView.swift` | W2 | One-off exception (asking the architect): drop the separate 64 pt number. Instead the first number *and the words right after it* are highlighted in amber, bold, inside the sentence itself (e.g. "can dive to **40 metres** below..."). The sentence stays verbatim and whole; no label is written by us. `FactFormatting.leadingNumber` becomes `highlightRange(in:)`, returning the range of the number plus its unit or following word. |
| Tests | | `FeedComposerTests`: no image repeats in any set across many fact/photo mixes; fact count capped by spare photos; existing pacing tests kept. `LayoutRulesTests`: highlight range covers number and unit, skips plain years, returns nil when there is no number. |

No new files, types, contracts, persisted keys or content sources.

## Content rules

Zero AI content (D-011) holds: the number is no longer pulled out of its sentence, it's only
styled where it already sits. Photos are unchanged apart from not repeating.

## Trade-off

Species with few photos get shorter sets (for example one spare photo → one fact card). The next
species arrives sooner instead of a photo repeating. Fact cards never show an empty photo slot.

Docs: product.md (set length, pacing, fact card), design.md (fact card), architecture.md
(FactCardView line), changelog, status.

## Part 2: the intro becomes a short fact sheet

Maxwell (2026-11-06): "the first screen should really be a fact sheet with core details and
attributes about the animal without being overwhelming or verbose ... ie, diet, range, size".
Only show a field when there is sourced data for it.

**What the sheet shows** (zoo-board, one short line per row, rows with no data are left out):
common and scientific name, lineage, IUCN bar (as today), then up to four rows:
**Lives in** (range), **Eats** (diet), **Size** (length or height or wingspan), **Weight**.
The lead paragraph and the "Did you know?" box leave the intro (the lead stays in the detail
sheet; the headline fact becomes the first fact card). If no row has data, the intro falls back
to the lead as today, so no intro is ever empty.

**Where the values come from** (none written by us, D-011):

| Row | Wikidata (CC0) | Coverage in the 361 bundled species |
| --- | --- | --- |
| Lives in | P9714 taxon range, else P183 endemic to (English labels of the places) | ~45% |
| Eats | P1034 main food source (English labels) | ~13% |
| Size | P2043 length, P2048 height, P2050 wingspan (amount + unit symbol) | ~15% |
| Weight | P2067 mass (amount + unit symbol; adult values preferred via P3831 qualifiers, shown as a min–max range when there are several) | ~22% |

Coverage is thin, so a second, optional source needs Maxwell's call (decision card in the
thread): when Wikidata has nothing, use **one short verbatim sentence** (at most ~90
characters) from the article's own Diet / Distribution and habitat / Description section,
picked by `FactExtractor`. Still sourced and verbatim, but wordier than a value.

Labels ("Lives in", "Eats", unit symbols like "kg") are UI chrome, not animal content.

**Pieces and owners** (the architect may prefer to split this into its own PR):

- Models (W1): `SpeciesProfile` value (`range: [String]`, `diet: [String]`, `size`, `weight` as
  sourced `ProfileValue { text, source: Attribution }`), added as an optional field on
  `SpeciesContent` (tolerant decode, data-model.md updated).
- Adapter (W1): `WikiClient` fetches the Wikidata entity's claims and the English labels of the
  referenced items (two `wbgetentities` calls, cached with the rest of `SpeciesContent`). Same
  path for bundled and live species.
- Pure logic (W4): `Services/SpeciesProfileBuilder.swift` turns raw claims + labels (+ optional
  article sections) into a `SpeciesProfile`: unit-symbol table, adult-value preference, number
  formatting, at most three places/foods per row. Fully unit-tested with recorded claims.
- View (W2): `IntroCardView` renders the rows in place of the lead/"Did you know?" box.

Known data risk: Wikidata ranges can be partial (Peregrine falcon lists only a couple of
countries). The row shows exactly what Wikidata says, with its source in the credit sheet.

## Open questions

1. OK for W4 to make the `FactCardView` change (W2's file), or should W2 do it?
2. Part 2 spans W1, W2 and W4 files. Split it into its own PR (W4 builds the builder and tests
   first, W1 and W2 wire it), or let W4 do all of it here as a one-off?
3. Maxwell: Wikidata only, or also the short-sentence fallback? (asked in the thread)
