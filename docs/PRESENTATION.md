# Presentation

Everything visual is generated at runtime. No third-party card or table assets.

- `TableBuilder` — felt, rails, brass, shoe, tray, discard, lamp, dealer pad, gold TextMesh markings
- `CardTextures` — 52 faces + back as `Image` / PBR quads on a thin box
- `CardView` — deal from the shoe, Y-up faces, Z flip for hole cards
- `ChipFactory` — denomination colors, clickable tray `Area3D`
- `TableView` — seated camera (FOV 56), ACES tonemap, tasteful bloom, sway, BJ push-in
- `GameHUD` — bankroll, bet, totals, session, context buttons
- `OverlayUI` — main / pause / settings / stats / how-to / tutorial
- `AudioManager` — procedural WAV tones on Master / Music / FX / Ambient
- `ResultVFX` — short GPU particles for BJ / win / bust / push

Animation duration is multiplied by `SettingsStore.anim_scale()`. Input is ignored while `_busy` so rapid keys cannot desync the table.
