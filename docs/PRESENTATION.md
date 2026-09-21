# Presentation

Everything visual is generated at runtime. No third-party card or table assets.

- `TableBuilder` — deep-green felt, layered rails, brass, branded wall, shoe, tray, discard, lamp, dealer pad, gold TextMesh markings
- `CardTextures` — 52 faces + back as `Image` / PBR quads on a thin box
- `CardView` — deal from the shoe, Y-up faces, Z flip for hole cards
- `ChipFactory` — denomination colors, clickable tray `Area3D`
- `TableView` — seated camera (FOV 53), ACES tonemap, quality-tier restrained bloom, SSAO, sway, BJ push-in
- `GameHUD` — bankroll, bet, totals, session, context buttons
- `OverlayUI` — main / pause / settings / stats / how-to / tutorial
- `AudioManager` — procedural WAV tones on Master / Music / FX / Ambient
- `ResultVFX` — short GPU particles for BJ / win / bust / push

Animation duration is multiplied by `SettingsStore.anim_scale()`. Input is ignored while `_busy` so rapid keys cannot desync the table.

Card faces use original raster artwork on unshaded anisotropic quads so ranks and suits remain crisp independently of table lighting. Player cards are enlarged and tilted toward the seated camera; the dealer up-card faces the player and only the hole card stays down before settlement.
