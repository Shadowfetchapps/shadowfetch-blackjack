# Architecture

Shadowfetch Blackjack splits **rules** from **presentation**.

```
BlackjackEngine  (RefCounted)
    BJShoe / BJHand / BJCard / BJMoney
           ▲
           │ commands + snapshots
           │
GameController (Node3D)
    TableView   3D world, cards, chips, camera
    GameHUD     action bar
    OverlayUI   menus
    AudioManager / ResultVFX / SettingsStore / StatsStore
```

The engine can run 100k hands in headless Godot with no scenes. The table never writes bankroll itself; it only calls engine methods and animates the result.

See `docs/ENGINE.md`, `docs/SHOE.md`, `docs/BETTING.md`, `docs/STATE.md`, `docs/PRESENTATION.md`, `docs/SAVE.md`, and `docs/TESTS.md`.
