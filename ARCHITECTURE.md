# Architecture

Shadowfetch Blackjack separates **rules** from **presentation**. The engine is a plain `RefCounted` object with no
nodes, tweens or timers; everything the player sees is a reaction to engine state.

```
                 ┌──────────────────────────── autoloads ────────────────────────────┐
                 │ SettingsStore  StatsStore  Achievements  AudioManager              │
                 └────────────────────────────────────────────────────────────────────┘
                                   ▲ record_round / rules / prefs
                                   │
 input ──► GameController (Node3D) ─── commands ───► BlackjackEngine (RefCounted)
            │   sequences each round with awaits       ├─ BJRules      table rules, house-edge estimate
            │                                          ├─ BJShoe       n-deck shoe, cut card, conservation
            │                                          ├─ BJHand/BJCard
            │                                          ├─ BJSideBets   Perfect Pairs, 21+3
            │                                          ├─ BJStrategy   basic strategy for the rules
            │                                          └─ BJMoney      integer cents, limits, formatting
            │
            ├─► TableView (Node3D)   cards, chips, spots, camera, lighting, baked textures
            │     TableBuilder · MeshKit · FeltPainter · PatternPainter · TextureBaker
            │     CardView · ChipStack · CameraRig · ResultVFX
            ├─► GameHUD (CanvasLayer)  bankroll, action bar, badges, banner, toasts, tutorial
            └─► OverlayUI (CanvasLayer) menus and pages (settings, rules, stats, history, …)
```

## Round flow

1. The player builds wagers on up to three spots (`main`, `pp`, `t3`). Nothing is deducted yet.
2. At the deal boundary the controller copies saved rules into the engine (`set_rules`), which may build a fresh
   shoe. The engine then deducts every wager, deals, and resolves side bets.
3. The controller asks `TableView.sync_cards()` to mirror the engine; it returns how long the animation takes and
   the controller `await`s it. The same call handles hits, splits, doubles, the hole-card flip and dealer draws.
4. Insurance / even money, the dealer peek, player decisions and settlement follow the same pattern:
   engine command → table/HUD reflect it → await → next step.
5. On settlement the engine produces a `round_record`. `StatsStore.record_round()` folds it into lifetime
   statistics and history; `Achievements.evaluate()` checks for unlocks.
6. The table is swept, `finish_round()` returns the engine to betting, and pending rule changes apply.

Rules never change mid-hand, the engine never touches nodes, and the table never changes money.

## Where things live

```
scripts/engine/   rules engine (pure GDScript, fully unit-tested)
scripts/table/    3D table: builder, meshes, painters, cards, chips, camera
scripts/ui/       theme, fonts, HUD, overlay + pages/, boot splash
scripts/game/     GameController, QA/screenshot harness
scripts/save/     SettingsStore, StatsStore, XDG paths
scripts/meta/     Achievements
scripts/audio/    AudioManager
scripts/vfx/      particle flourishes
assets/           cards, chips, HUD chips, audio, fonts, shaders (all original / OFL)
tests/            unit suites, simulation, edge check, runner
tools/            export, packaging, install, asset generators
```

Deeper dives: [docs/ENGINE.md](docs/ENGINE.md), [docs/PRESENTATION.md](docs/PRESENTATION.md),
[docs/UI.md](docs/UI.md), [docs/SAVE.md](docs/SAVE.md) and [docs/TESTS.md](docs/TESTS.md).
