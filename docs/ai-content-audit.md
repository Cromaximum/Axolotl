# AI-content audit

Audit against D-011 (zero AI-generated content), done 2026-11-06 on `main` at `805efe2`.
Update this file as items are fixed: tick them off and add the PR number.

## Summary

The app's runtime content (facts, lead text, taglines, photos) is pulled live from Wikipedia and
Commons and shown verbatim, so it already follows the rule. The **bundled species data** and the **mockup text** were
written by an AI agent and must be replaced with sourced values.

## Findings

| # | Where | What is AI-written | Severity | Proposed fix |
| --- | --- | --- | --- | --- |
| 1 | `tools/gen_taxonomy.py` → `taxonomy.json` | **IUCN status** for all 77 species, typed from an AI model's memory | High: shown to users as fact on every intro card | Regenerate from Wikidata P141 (IUCN conservation status, CC0). Species without a value get `NE`. |
| 2 | same | **Common names** of the 77 species (e.g. "Water bear", "Immortal jellyfish") | High: shown on every card | Use the English Wikipedia article title / Wikidata English label, or Wikidata P1843 (taxon common name, English). |
| 3 | same | **Group names** for the 122 tree nodes (e.g. "Elephants and kin", "Even-toed ungulates", "Turritopsids") | Medium: shown in the filter and lineage line | Use Wikidata English labels for each taxon, falling back to the scientific name. |
| 4 | same | **Tree structure** (which species sit under which family/order/class) | Medium: affects filtering, and some placements are simplified | Build the tree from Wikidata P171 (parent taxon) up to the kingdom, keeping only the ranks we show. |
| 5 | same | **Species selection** (which 77 animals) | Low: a curation choice, not content | Fine to keep as a human-reviewed list of Wikidata QIDs; Maxwell or the collaborator should approve the list. |
| 6 | `Services/ContentPolicy.swift` | No check for **AI-generated images** on Commons | Not needed | **Won't do** (Maxwell, 2026-11-06): images come only from the species' own Wikipedia article, and Wikipedia doesn't allow AI images. Keep it that way (content-and-licensing rule 4). |
| 7 | `docs/design/concept-art/` (prototype, screens) | **Fact text** on the mockups was "written from" Wikipedia, i.e. paraphrased, e.g. "It can't roar. It chuffs, hisses and yowls instead." | Low: design docs, not the app, but could be copied into it | Replace with verbatim sentences from each article, with the article credited on screen. |
| 8 | UI strings in `Features/` and mockups (onboarding lines, footers, button labels) | Interface copy drafted by AI | Low: not animal content | Covered by rule 6 in [content-and-licensing.md](content-and-licensing.md#zero-ai-generated-content): a human writes or approves interface copy before release. |

## What already complies

- Live-catalogue species (D-012): common name = English Wikipedia article title, scientific
  name and lineage = GBIF Backbone, IUCN status = Wikidata P141, else Extinct only when GBIF flags it, else "Unknown" with no
  IUCN bar (never inferred from keywords). Nodes not in
  the bundled tree show only their scientific name. Nothing is typed in.
- `FactExtractor` picks whole sentences from the plain-text article and never rewrites them.
- `WikipediaContentProvider.lead` keeps the first one or two whole sentences of the summary.
- `tagline` is Wikipedia's own short description.
- Photos come straight from Commons with author and licence.
- `CREDITS.md` for the concept art lists real Commons photos with their licences.

## Proposed replacement pipeline (fixes 1 to 4)

1. Keep a human-reviewed list of species as Wikidata QIDs in `tools/species.txt`.
2. `tools/gen_taxonomy.py` queries the Wikidata SPARQL endpoint (CC0) for each QID: English label,
   English Wikipedia sitelink (becomes `wikiTitle`), scientific name (P225), IUCN status (P141),
   and the parent-taxon chain (P171) with each ancestor's rank (P105) and English label.
3. It writes `taxonomy.json` plus a `source` field per value (QID and property), so every value
   can be traced. No hand-typed values remain.
4. CI or a test checks that every species has a QID and that no field was edited by hand
   (regenerate and diff).

This can run from the cloud environment if Wikidata (`query.wikidata.org`) is reachable, or on
a Mac.

## Checklist

- [x] 1 to 4: Regenerated `taxonomy.json` from Wikidata and Wikipedia (#9)
- [ ] 5: Species list approved by a human
- [x] 6: Not needed; images only from the species' Wikipedia article
- [ ] 7: Verbatim text in concept mockups
- [ ] 8: Interface copy reviewed by a human before TestFlight
