# Content and licensing rules

These rules are **hard requirements**. Breaking them can get the app pulled or create legal
liability. If a change would loosen any of them, stop and get a human decision recorded in
[decisions.md](decisions.md).

## Sources (Phase 1)

| Content | Source | Licence |
| --- | --- | --- |
| Lead text, facts, short description | English Wikipedia | CC BY-SA 4.0 |
| Images | Wikimedia Commons files used on the species' English Wikipedia article | Per file (see allowlist) |
| Conservation status | IUCN Red List category, entered by hand in `tools/gen_taxonomy.py` | Facts, not copyrightable; verify before launch |
| Taxonomy | Hand-curated in `tools/gen_taxonomy.py` | n/a |

No other sources in Phase 1. In particular: no scraping of other websites, no stock photo
sites, no YouTube, no social media, no AI-generated images.

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

## Image suitability

`ContentPolicy.licensedImages` also drops:

- Non-photo MIME types (only JPEG, PNG, WebP).
- Images narrower than 400 px.
- "Junk" files whose names suggest maps, range maps, status icons, logos, stamps, coins,
  charts, cladograms, size comparisons, and Wikimedia UI icons.

## Paleoart and reconstructions

Decision D-005. Rules:

1. Only for **extinct** species. Living species only ever show photographs.
2. Only from reputable sources (museums, journals, recognised paleoartists). Phase 1 enforces
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
