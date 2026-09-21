# Save format

XDG paths (overridable with `SHADOWFETCH_BJ_HOME` for tests):

| File | Location |
| --- | --- |
| Settings | `~/.config/shadowfetch-blackjack/settings.json` |
| Stats | `~/.local/share/shadowfetch-blackjack/stats.json` |

Corrupt JSON or out-of-range values restore defaults and log a warning. The game does not crash.

Settings include resolution, fullscreen, vsync, quality, AA, shadows, animation speed, four volume sliders, mute, and `seen_tutorial`.

Stats include bankroll, last/previous bet, lifetime and session P/L, hands, wins, losses, pushes, blackjacks, largest win.
