# Design

Visual language: **zoo information boards** (decision D-003). The concept deck has the original
mockups: https://claude.ai/artifact/2AV6oC69cT5XeUxaphfNHU.

**Concept screens:** [`design/`](design/README.md) has twelve full-screen concept screens built
from real Wikimedia Commons photos (welcome, onboarding, intro card, photo, fact, wide photo,
extinct, fossil, reconstruction, species detail, tree filters, species collection). Open
`design/concept-art/prototype.html` in a browser. Treat them as the target look; the rules below
win where they conflict.

## Palette (`App/Theme.swift`)

| Token | Hex | Use |
| --- | --- | --- |
| `forest` | `#14261F` | App background |
| `boardGreen` | `#1F3B2F` | Sign panel |
| `wood` | `#6B4A2B` | Sign frame (6 pt border) |
| `parchment` | `#F5F0E6` | Fact boxes, light panels |
| `amber` | `#E2A13B` | Accents, "Did you know?", selected state |
| `ink` | `#1E1B16` | Text on parchment |

Use the `Theme` tokens. Don't add raw colour literals in views.

## Type

- Headings: **Fredoka SemiBold** (`Theme.heading`)
- Body: **Nunito Sans** Regular / Bold (`Theme.body`, `Theme.label`)
- Both are OFL (Google Fonts). The `.ttf` files are not bundled yet; until they are, the helpers
  fall back to the system font. To add them, drop the files in `AnimalScroller/Resources/Fonts/`
  and list them under `UIAppFonts` in `project.yml`.
- Fonts use `relativeTo:` so Dynamic Type still scales.

## Card anatomy

- **Intro card**: hero photo on top; a `BoardPanel` sign with common name (large), scientific
  name (italic), taxonomic path, lead text, an amber "Did you know?" box, and the IUCN status bar
  with the species' category highlighted. "ARTIST RECONSTRUCTION" tag if the hero is artwork.
- **Photo card**: full-bleed image, caption if any, attribution chip, reconstruction tag when
  relevant.
- **Fact card**: board with the article section as heading (e.g. "Diet"), the fact, and an
  "n of N" counter.
- **Attribution chip** on every card; opens a credit sheet.

## Rules

- Dark appearance, portrait only.
- Keep text legible over photos (scrims/gradients), and respect Dynamic Type.
- Living species: photographs only. Artwork must carry the reconstruction tag.
- **Species first, information second** (D-010). The animal gets the frame; the eye finds the text
  after. Photos run edge to edge. Text never sits across the animal: it goes in the bottom
  zoo-board panel or on a scrim in the lower third, and chips hug the top and bottom edges.
- Crop so the animal's head is in the top ~55% of the screen. Wide photos that would lose the
  animal in a portrait crop are shown full-width over a blurred copy of themselves.
- Fact cards keep the photo on top and show one number or one sentence on the board below.
- Extinct-species media is tagged: `Historical photo`, `Real fossil`, or amber `Reconstruction`.
