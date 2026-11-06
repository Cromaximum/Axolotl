# Content and licensing rules

These rules are **hard requirements**. Breaking them can get the app pulled or create legal
liability. If a change would loosen any of them, stop and get a human decision recorded in
[decisions.md](decisions.md).

## Zero AI-generated content

Decision D-011 (Maxwell Rhinelander, 2026-11-06). This is the most important rule in the project.

**The app contains no AI-generated content of any kind: no words, no pictures, nothing.** Every
fact, caption, description, name, status, image, sound or clip a user sees comes from an open
source, unchanged, with attribution.

What this means in practice:

| Allowed | Not allowed |
| --- | --- |
| Wikipedia sentences shown **verbatim** (whole sentences, cut only at sentence boundaries) | AI-written, AI-summarised, AI-paraphrased, AI-"cleaned up" or AI-translated text |
| Wikidata values (CC0): names, taxonomy, IUCN status | Names, statuses or taxonomy typed in from an AI model's memory |
| Commons photos, fossils, specimens, human-made paleoart | AI-generated or AI-upscaled/edited images, even if Commons hosts them under a free licence |
| Code that selects, filters, orders and crops sourced content | Code that generates or rewrites content (LLM calls, image generation) |
| Agents writing code, tests and docs | Agents writing anything that ships as content, including "placeholder" facts |

Rules for agents and contributors:

1. **Never author content.** If a card needs text and no source has it, leave the slot empty or
   drop the card. Do not fill it in.
2. **Quote, don't rewrite.** Text keeps the source's wording. Trimming to whole sentences is fine;
   rewording, merging sentences or "simplifying" is not.
3. **Every value has a source.** Data in `taxonomy.json` (common names, group names, IUCN status)
   must come from Wikidata or Wikipedia, not from memory. Record where it came from.
4. **Images only from the species' Wikipedia article.** Use Commons files that are actually
   used on the species' English Wikipedia article, never a free search of Commons. Wikipedia
   doesn't allow AI-generated images in articles, so this is how AI images are kept out; there
   is deliberately no separate AI-image filter (Maxwell, 2026-11-06). If a new source would bring
   in images that aren't vetted this way, update this rule first.
5. **Mockups too.** Design mockups and screenshots in `docs/` should use verbatim sourced text,
   so nobody copies invented text into the app.
6. **Interface text** (buttons, menus, onboarding) is not animal content, but it must be
   written or approved by a human before release. Agents may draft it; mark drafts in the PR.

The current audit of AI-written material in the repo, and the plan to replace it, is in
[ai-content-audit.md](ai-content-audit.md).

## Sources (Phase 1)

| Content | Source | Licence |
| --- | --- | --- |
| Lead text, facts, short description | English Wikipedia | CC BY-SA 4.0 |
| Images | Wikimedia Commons files used on the species' English Wikipedia article | Per file (see allowlist) |
| Conservation status | IUCN Red List category via Wikidata (P141) | CC0. **Currently typed in by hand; must be replaced, see [ai-content-audit.md](ai-content-audit.md)** |
| Taxonomy and common names | Wikidata (parent taxon P171, English labels / common names P1843) | CC0. **Currently typed in by hand; must be replaced** |
| Intro fact sheet values (lives in, eats, length/height/wingspan, weight) | Wikidata statements on the article's item: P9714 taxon range / P183 endemic to, P1034 main food source, P2043 / P2048 / P2050, P2067 mass; place and food names are the items' English labels | CC0. Credited as "Sources: Wikidata (CC0)" on the sheet |
| Intro fact sheet fallback | One whole sentence (at most 90 characters) from the matching section of the species' English Wikipedia article | CC BY-SA 4.0 (Maxwell approved the fallback, 2026-11-06, D-017) |
| Live catalogue: species list, scientific names, classification | GBIF Backbone Taxonomy (`api.gbif.org`, built on the Catalogue of Life) | CC BY 4.0. Credited on the species detail sheet with a link to the GBIF species page |
| Live catalogue: common name | The species' English Wikipedia article title, verbatim (a trailing "(animal)"-style disambiguator is dropped) | CC BY-SA 4.0 (part of the article credit) |
| Live catalogue: conservation status | Wikidata P141 on the article's Wikidata item, else Extinct only if GBIF flags the species extinct | CC0. No sourced value → the IUCN bar is left out and the status reads "Unknown". Never guessed from keywords; Extinct only when Wikidata or GBIF states it (Maxwell, D-012) Never GBIF's `iucnRedListCategory` endpoint: that IUCN data is NonCommercial |

The live catalogue (D-012) never adds a new content source: GBIF supplies only which species
exist and where they sit in the tree. Every live species must have an English Wikipedia article
with a freely licensed lead image, and its cards are built from that article and the Commons
files used on it, exactly like bundled species. Live species whose article is a stub
(< 5,000 bytes), redirects to a genus or family, or yields no usable photo or fewer than two
facts are skipped. Images used on Wikipedia articles are treated as real photographs, because
Wikipedia does not allow AI-generated images (Maxwell, 2026-11-06).

No other sources in Phase 1. In particular: no scraping of other websites, no stock photo
sites, no YouTube, no social media, no AI-generated anything (see above).

## Licence allowlist

| Licence | Allowed | What we must do |
| --- | --- | --- |
| Public domain, CC0 | Yes | Credit anyway, as a courtesy |
| CC BY (any version) | Yes | Show author, licence and link on screen |
| CC BY-SA (any version) | Yes | Same credit; any edited version stays under the same licence |
| Anything NonCommercial (NC) | **No** | The app runs ads |
| Anything NoDerivatives (ND) | **No** | We crop images to fill the screen |
| Fair use, non-free, all rights reserved, GFDL-only, unknown | **No** | Not usable without a deal |

Implementation: `ContentPolicy.isAllowedLicense` (`AnimalScroller/Services/ContentPolicy.swift`),
tested in `AnimalScrollerTests/ContentPolicyTests.swift`. If you change it, add test cases for
every licence string you touch. Reject when in doubt.

## Attribution

- Every card carries an `Attribution` (title, author, licence, licence URL, source URL).
- Photos credit the Commons file's author and licence and link to its file page.
- Text cards credit "Wikipedia contributors · CC BY-SA 4.0" and link the article.
- The attribution chip must be visible on every card and open a credit sheet.

## Captions

Photo captions are the Commons file's `ImageDescription`, HTML stripped, otherwise verbatim.
`ContentPolicy.wholeSentenceCaption` keeps as many whole sentences as fit in 200 characters; if
the first sentence alone is longer, the photo has no caption. Captions are never cut mid-sentence
(D-011). The species detail sheet shows Wikipedia's short description as-is ("Wikipedia says").

## Facts

"Did you know?" facts are whole sentences copied verbatim from the species' English Wikipedia
article (D-011). `FactExtractor` only *chooses* sentences; it never edits them. It skips
sections such as References, Etymology and Taxonomy, and rejects sentences that:

- open with words that need the previous sentence ("It", "This", "As a result", "Later", ...),
- carry citation residue or point elsewhere ("et al.", "ISBN", "see below", "Figure"),
- restate the taxonomy the intro board already shows ("is a species of", "was described by"),
- read as lists (a colon, or four or more commas), or
- say nearly the same thing as a fact already picked or as the lead.

It prefers sentences with numbers and units (sizes, weights, ages) and marks down hedged ones
("may", "is thought").

## Intro fact sheet

`SpeciesProfileBuilder` builds up to four rows, and a row exists only when a source has the data
(D-017):

- **Wikidata first.** Place and food names are item labels exactly as Wikidata has them, at most
  three per row. Quantities are Wikidata's amounts as sent (only the leading "+" dropped) with a
  unit symbol; several adult values become a min–max range; values whose "object has role"
  qualifier says newborn, juvenile, egg and so on are skipped. Unknown units are skipped.
- **Wikipedia fallback.** When Wikidata has nothing for a row, the first standalone sentence of
  at most 90 characters from the matching article section (Distribution and habitat, Diet,
  Description...) that passes `FactExtractor.isStandalone`; size and weight sentences must
  contain a length or mass measurement. Copied whole, never trimmed or rewritten.
- Wikidata ranges can be partial; the row shows what Wikidata says, nothing is added.
- Row labels ("Lives in", "Eats", "Weight", unit symbols) are UI chrome.

## Image suitability

`ContentPolicy.licensedImages` also drops:

- Non-photo MIME types (only JPEG, PNG, WebP).
- Images narrower than 640 px (Commons scales to at most 1080 px wide, so narrower means a small
  original), with a short side under 400 px, or with an aspect ratio beyond 2.6:1 (panoramas
  and strips).
- "Junk" files whose names suggest maps, range maps, status icons, logos, stamps, coins,
  charts, cladograms, size comparisons, and Wikimedia UI icons.

## Paleoart and reconstructions

Decision D-005. Rules:

1. Only for **extinct** species. Living species only ever show photographs.
2. Only human-made, from reputable sources (museums, journals, recognised paleoartists). Phase 1 enforces
   this by only using artwork already used on the species' English Wikipedia article, where
   palaeontology editors review reconstructions.
3. Always labelled "Artist reconstruction" on the card.
4. Users can turn them off ("Show artist reconstructions").

Artwork is detected by keywords in the file name and description (`ContentPolicy.isArtwork`).
It is imperfect: when in doubt, treat an image as artwork.

## Wikimedia API etiquette

- Send a descriptive `User-Agent` with a way to contact the developer
  (https://meta.wikimedia.org/wiki/User-Agent_policy). The current value in `WikiClient` has a
  placeholder contact that must be replaced before release.
- Cache aggressively (the app sets a 512 MB `URLCache`) and don't hammer the API.

## Future content (not allowed yet)

Phase 2 plans Commons video and sounds; Phase 3 plans licensed partner footage. Neither may be
added without a decision entry and updated rules here.
