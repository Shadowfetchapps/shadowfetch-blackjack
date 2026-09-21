# Shadowfetch Blackjack

Premium standalone **3D blackjack** for Linux. Native Godot 4 / Vulkan desktop app — not a web page, not Electron.

You play seated at a cinematic casino table with readable 3D cards, tactile chips, and a rules-correct six-deck shoe. **All chips are fictional.** There is no cash-out, no deposits, and no real-money gambling.

![Dealt player and dealer cards](docs/screenshots/deal.png)

![Split hands facing the player](docs/screenshots/split.png)

**Version:** 1.0.0  
**App name:** Shadowfetch Blackjack

## Features

- Seated first-person camera over a PBR felt table with markings, shoe, tray, and dealer station
- Full 52-card faces plus backs, dealt with flip / slide / split / reveal / clear
- Chips: $1 / $5 / $25 / $100 / $500 / $1000, stack, undo, clear, rebet, repeat
- $10,000 starting fictional bankroll, persisted stats, reset option
- Six-deck shoe, real shuffle, cut card, reshuffle
- Dealer stands on **all 17s** (including soft 17)
- Blackjack pays **3:2**, insurance **2:1**, DAS, split to four hands, conventional split aces
- Context-sensitive HUD and keyboard shortcuts
- Master / Music / FX / Ambient volumes, mute, graphics quality, resolution, fullscreen, vsync, AA, shadows, animation speed
- Beginner tutorial and How To Play
- User-local Linux install (`.desktop` + icon sizes)

## Controls

| Key | Action |
| --- | --- |
| Space | Deal |
| H | Hit |
| S | Stand |
| D | Double |
| P | Split |
| R | Repeat last bet and deal |
| Esc | Pause / menu |

Chip buttons (and the 3D tray) add to the wager. Invalid shortcuts are ignored.

## Rules (this table)

- Six decks, shuffled; a cut card triggers a reshuffle after the current hand
- Dealer stands on hard and soft 17
- Natural blackjack pays 3:2; both sides blackjack is a push
- Split matching **ranks** only, maximum four hands
- Double after split allowed; split aces receive one card each and cannot be hit, doubled, or resplit
- Insurance is offered on a dealer Ace for half the original bet
- Bankroll is tracked in integer cents and cannot go negative

## Install (user-local)

From a release build or a local export:

```bash
./tools/install-user.sh
```

This installs:

- `~/.local/bin/shadowfetch-blackjack`
- `~/.local/share/applications/com.shadowfetch.Blackjack.desktop`
- `~/.local/share/icons/hicolor/*/apps/shadowfetch-blackjack.png`

Launch **Shadowfetch Blackjack** from your app menu, or run `shadowfetch-blackjack` if `~/.local/bin` is on `PATH`.

No configuration is required on first launch.

## Source, build, test

Requirements: [Godot 4.7](https://godotengine.org/) (this project targets 4.7.2), Linux x86_64, Vulkan.

```bash
# Engine unit tests + 100k+ simulated hands
./tools/run_tests.sh

# Editor / play
godot --path .

# Release export
./tools/export_linux.sh
```

`SHADOWFETCH_BJ_HOME` redirects settings/stats for tests so developer runs do not touch your real save files.

## Architecture

The rules engine is independent of the 3D table. See `docs/` for engine, shoe, betting, presentation, save format, and tests.

```
scripts/engine/     shoe, hands, payouts, legal actions
scripts/save/       settings + stats (corrupt-safe)
scripts/table/      procedural table, cards, chips, camera
scripts/ui/         HUD, menus, tutorial
scripts/game/       table session / animation orchestration
tests/              headless Godot suite + large simulation
```

## License

MIT. Original procedural art and audio. No third-party casino IP.

## Disclaimer

This is a single-player video game that uses **play money**. It is not a gambling service.
