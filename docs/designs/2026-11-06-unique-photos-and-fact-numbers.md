# Design: Shorter species sets, no repeated photos, no context-free big numbers

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

## Open questions

1. OK for W4 to make the `FactCardView` change (W2's file), or should W2 do it?
