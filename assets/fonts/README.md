# Bundled fonts

All fonts in this directory are redistributed unmodified under the
SIL Open Font License, Version 1.1 (see `OFL.txt` in this directory).

| File | Family / style | Copyright holder | License |
| --- | --- | --- | --- |
| `NotoSerifDisplay-Bold.ttf` | Noto Serif Display Bold | © Google LLC / The Noto Project Authors | OFL-1.1 |
| `NotoSerifDisplay-SemiBold.ttf` | Noto Serif Display SemiBold | © Google LLC / The Noto Project Authors | OFL-1.1 |
| `Inter-Regular.otf` | Inter Regular | © The Inter Project Authors | OFL-1.1 |
| `Inter-Medium.otf` | Inter Medium | © The Inter Project Authors | OFL-1.1 |
| `Inter-SemiBold.otf` | Inter SemiBold | © The Inter Project Authors | OFL-1.1 |
| `Inter-Bold.otf` | Inter Bold | © The Inter Project Authors | OFL-1.1 |
| `NotoSansSymbols2-Regular.ttf` | Noto Sans Symbols 2 (suit and symbol fallback) | © Google LLC / The Noto Project Authors | OFL-1.1 |

Sources:

- Inter: <https://github.com/rsms/inter>
- Noto Serif Display: <https://github.com/notofonts/latin-greek-cyrillic>
- Noto Sans Symbols 2: <https://github.com/notofonts/symbols>

Noto Serif Display is used for card indices, chip denominations and display
headings; Inter is used for small UI text. The card and chip generators in
`tools/` also read these files, so the rendered artwork is reproducible.
