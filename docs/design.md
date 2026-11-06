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
| `mist` | `#C9D6CF` | Secondary text |

Use the `Theme` tokens. Don't add raw colour literals in views.

## Type

- Headings: **Fredoka SemiBold** (`Theme.heading`)
- Body: **Nunito Sans** Regular / Bold (`Theme.body`, `Theme.label`)
- Both are OFL (Google Fonts). The `.ttf` files are not bundled yet; until they are, the helpers
  fall back to the system font. To add them, drop the files in `AnimalScroller/Resources/Fonts/`
  and list them under `UIAppFonts` in `project.yml`.
- Fonts use `relativeTo:` so Dynamic Type still scales.

## Card anatomy

Implemented to match the concept screens (shared pieces in `Features/Components/CardComponents.swift`):

- **Intro card** (screen 3/7): hero full-bleed; zoo-board sign at the bottom (green panel,
  6 pt wood border, 22 pt corners) with common name, scientific name in amber italic, lineage in
  mist, parchment "Did you know?" box, IUCN bar with status label and "IUCN Red List". Progress
  dashes or the media tag top-left, credit chip top-right.
- **Photo card** (screen 4/6/8/9): animal only. "Name · n of N" pill top-left, credit chip
  bottom-left, Save / Info / Share rail on the right. Extinct: media tag top-left, credit
  top-right, amber "SCIENTIFIC NAME · n OF N" and the caption on a lower-third scrim.
- **Fact card** (screen 5): photo in the top 52% with its credit; forest board below with a
  5 pt wood rule, "DID YOU KNOW? · TOPIC" in amber, the stand-out number at 64 pt, the sentence
  in Fredoka, and "Scientific name · Source: Wikipedia".
- **Species detail** (screen 10), **Tree** (screen 11), **Species met** (screen 12), **Welcome**
  and **Starting point** (screens 1–2).
- **Credit chip** on every photo; opens a credit sheet.
- Not built yet from the concept: photo thumbnails on Tree rows, drill-down pages per rank,
  "Eats" / "Lives in" quick facts (need structured data).

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
