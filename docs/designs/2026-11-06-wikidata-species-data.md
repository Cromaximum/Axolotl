# Design: Rebuild bundled species data from Wikidata

- Author: Claude (thread "Keep app content free of AI"), asked for by Maxwell Rhinelander
- Date: 2026-11-06
- Status: Design approved (architect, PR #9)

## Problem

D-011 (zero AI-generated content). The audit (`docs/ai-content-audit.md`, items 1 to 4) found
that common names, group names, IUCN statuses and tree placement in `taxonomy.json` were typed in
by an AI agent. Maxwell approved replacing them with sourced values. He also decided there is no
AI-image filter: images come only from each species' own Wikipedia article, and Wikipedia bans
AI images (recorded in `content-and-licensing.md` rule 4 and D-011).

## Where it goes

Data layer only (`tools/`, `Resources/`). No Swift changes.

| File | Responsibility |
| --- | --- |
| `tools/species.txt` (new) | The only hand-made input: English Wikipedia titles of the species to include (curation, not content). |
| `tools/gen_taxonomy.py` (rewritten) | Fetches every value from Wikidata / English Wikipedia and writes `taxonomy.json`. `--check` fails if the JSON differs from what the sources produce (catches hand edits). |
| `tools/taxonomy-sources.json` (new, generated) | Provenance: the Wikidata item and property behind every species and taxon value. |
| `AnimalScroller/Resources/taxonomy.json` | Regenerated. Same shape. |
| `tools/.cache/` (git-ignored) | Cached API responses so re-runs don't hit Wikidata again. |

## Data flow

```
species.txt → enwiki API (redirects, wikibase_item) → Wikidata wbgetentities
  → P225 scientific name, P141 IUCN status, P31 fossil taxon, P171 parent chain, P105 rank,
    enwiki sitelink titles → taxonomy.json (+ taxonomy-sources.json)
```

- Common name = English Wikipedia article title; when that title is just the scientific name,
  the first English Wikidata P1843 (taxon common name) instead. Group name = the taxon's English Wikipedia
  title (disambiguator stripped), else its P225. Same convention as the live catalogue thread.
- Status = P141 mapped to LC/NT/VU/EN/CR/EW/EX/DD. No P141 and P31 = fossil taxon → EX.
  Else the IUCN status in the article's taxobox (`status` with `status_system = IUCN…`).
  Otherwise NE.
- Tree keeps kingdom, phylum, class, order, family. Species hang under the nearest kept rank.
- The script checks the English labels of every Wikidata id it hard-codes (ranks, statuses,
  fossil taxon, Animalia) at run time and stops if one doesn't match, so no id is trusted from
  memory.
- Requests are paced (1/s) with backoff on HTTP 429; Wikidata rate-limits cloud IPs heavily.

## New contracts

None in Swift. `taxonomy.json` keeps its shape (`Taxon` / `Species` decode unchanged).
`tools/taxonomy-sources.json` is new but not bundled or read by the app.

## Effect on the data (77 species, 124 taxa)

- 4 statuses change. 9 species have no IUCN status in either Wikidata or the taxobox and show
  `NE`. 4 more (Tuatara, Dryococelus, Diving bell spider, Chambered nautilus) get theirs from the
  taxobox. Extinct count stays 20 (10 via P141, 10 via fossil taxon).
- 11 common names change: to the article title, or to P1843 where the title is scientific
  ("Orchid mantis" stays, from P1843; "Water bear" → "Hypsibius dujardini", which has no P1843).
- 12 scientific names change; fossil animals whose article is about the genus now show the genus
  ("Tyrannosaurus rex" → "Tyrannosaurus").
- Group names become Wikipedia titles ("Mammals" → "Mammal", "Cats" → "Felidae").
- 113 of 122 taxon ids are kept; 9 change because Wikidata's tree differs (e.g. `cetacea`,
  `dinosauria`, `actinopterygii` are not ranked order/class there). The onboarding tile ids in
  PR #4 (`mammalia`, `aves`, `reptilia`, `amphibia`, `insecta`, `malacostraca`) are all kept.
- 7 species ids (`wikiTitle`) change to the canonical article title after redirects.
  `species.txt` lists the canonical titles.

## Content rules

No new runtime source. Wikidata is CC0; Wikipedia titles are facts. No value is hand-typed. No
animal content is added to Swift. Interface copy untouched.

## Tests

`python3 tools/gen_taxonomy.py --check` (needs network or a warm cache). Not added to CI yet,
because CI can't count on reaching Wikidata; proposed as a follow-up once the cache can be
committed or CI gets access. Swift tests are unaffected: `FeedComposerTests` builds its own
`Taxon`.

## Open questions

Both are implemented as recommended and waiting on Maxwell's confirmation; either is a one-line
revert in `gen_taxonomy.py`.

1. **Common names for invertebrates.** Wikidata P1843 (taxon common name, English) would give
   "orchid mantis", "water bear" instead of scientific names. It's sourced too, but often has
   several values and lowercase. Use it when the article title is the scientific name? (Human
   decision; the live catalogue thread should follow the same answer.)
2. **Missing statuses.** 13 species get `NE` because Wikidata lacks P141, although IUCN has
   assessed some of them. Accept `NE`, or add a sourced fallback (Wikipedia taxobox `status`)?
