# Bundled fonts

Fredoka (headings) and Nunito Sans (body), both SIL Open Font License 1.1. The licence texts sit
next to the files and must stay with them. Neither font has a Reserved Font Name.

The `.ttf` files are the `.woff2` latin subsets in `docs/design/concept-art/fonts/`, decompressed
to TrueType with fontTools. That changes only the container, not the glyphs:

```sh
pip install fonttools brotli
python3 -c "from fontTools.ttLib import TTFont; f = TTFont('in.woff2'); f.flavor = None; f.save('out.ttf')"
```

| File | From | PostScript name (`Theme.FontName`) |
| --- | --- | --- |
| `Fredoka-Medium.ttf` | `fredoka-latin-500-normal.woff2` | `FredokaLight-Medium` |
| `Fredoka-SemiBold.ttf` | `fredoka-latin-600-normal.woff2` | `FredokaLight-SemiBold` |
| `NunitoSans-Regular.ttf` | `nunito-sans-latin-400-normal.woff2` | `NunitoSans12ptExtraLight12pt-Regular` |
| `NunitoSans-SemiBold.ttf` | `nunito-sans-latin-600-normal.woff2` | `NunitoSans12ptExtraLight12pt-SemiBold` |
| `NunitoSans-Bold.ttf` | `nunito-sans-latin-700-normal.woff2` | `NunitoSans12ptExtraLight12pt-Bold` |
| `NunitoSans-ExtraBold.ttf` | `nunito-sans-latin-800-normal.woff2` | `NunitoSans12ptExtraLight12pt-ExtraBold` |

The latin subset covers Basic Latin and Latin-1 (é, ü, ñ, œ) but not Latin Extended-A (ā, ł);
iOS draws those characters in the system font. There is no italic face, so scientific names use
the system italic (`Theme.scientific`). Adding new files: list them under `UIAppFonts` in
`project.yml` and add the PostScript name to `Theme.FontName`.
