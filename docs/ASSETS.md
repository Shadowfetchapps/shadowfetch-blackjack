# Asset provenance

Shadowfetch Blackjack ships no third-party casino branding, artwork, music, sound effects, models or texture packs.
Every asset is original to this project and reproducible from the scripts in `tools/`.

| Asset | Where | Made by |
| --- | --- | --- |
| Card faces (classic and four-colour), four card backs | `assets/cards/` | `tools/generate_cards.py` — vector suit shapes, original art-deco court designs |
| Chip faces, edge bands, HUD chips | `assets/chips/`, `assets/ui/` | `tools/generate_chips.py` |
| Music, ambience, effects | `assets/audio/` | `tools/generate_audio.py` — pure synthesis |
| Felt print, carpet, wallpaper, art, sign, placard | generated at runtime | `scripts/table/felt_painter.gd`, `pattern_painter.gd` |
| Table, room, cards, chips geometry | generated at runtime | `scripts/table/table_builder.gd`, `mesh_kit.gd` |
| Shaders | `assets/shaders/` | Original |
| Application icon | `icon.svg`, `data/icons/` | Original SVG; PNG sizes via `tools/generate-icons.sh` |
| Screenshots | `docs/screenshots/` | Captured from the game with `SF_BJ_QA=shots` |

## Fonts

Bundled unmodified under the SIL Open Font License 1.1 (see `assets/fonts/OFL.txt` and `assets/fonts/README.md`):
Inter (© The Inter Project Authors), Noto Serif Display and Noto Sans Symbols 2 (© Google LLC / The Noto Project
Authors). The card and chip generators use the same fonts.

All project code and original assets are released under the repository's MIT License.
