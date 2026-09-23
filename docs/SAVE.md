# Saves

XDG locations (both redirected by `SHADOWFETCH_BJ_HOME` for tests and QA):

| File | Location | Contents |
| --- | --- | --- |
| `settings.json` | `~/.config/shadowfetch-blackjack/` | Display, audio, gameplay, appearance, accessibility, table rules (schema v3) |
| `stats.json` | `~/.local/share/shadowfetch-blackjack/` | Bankroll, last bets, lifetime counters, session bankroll trail (schema v2) |
| `history.json` | `~/.local/share/shadowfetch-blackjack/` | The last 60 round records |
| `achievements.json` | `~/.local/share/shadowfetch-blackjack/` | Unlocked achievement ids with unix timestamps |

## Safety

- Every write goes to a temporary file that is then renamed over the old one, so a crash never leaves half a save.
- A file that cannot be parsed is copied aside as `<name>.corrupt` and defaults are restored; the game never crashes
  on bad data. Every value is validated and clamped (unknown enums, impossible resolutions, negative bankrolls…).
- A hand in progress is never saved: quitting mid-hand resumes with the bankroll from before the deal.

## Migration

- **Settings v1/v2 → v3:** existing volumes, quality, resolution, animation speed and the tutorial flag are kept;
  v2's top-level `dealer_hits_soft_17` / `late_surrender` move into `rules`; new options get defaults. The file is
  rewritten as v3 on first load.
- **Stats v1 → v2:** bankroll, hands, wins/losses/pushes, blackjacks, largest win, lifetime P/L and last bet (as the
  rebet) are kept; new counters start at zero; the chart trail starts at the current bankroll.

Both migrations are covered by tests that load the exact files written by 1.x/2.x.

## Statistics tracked

Hands, rounds, wins, losses, pushes, blackjacks, best win streak, largest round win, total wagered, doubles (and
doubles won), splits, surrenders, insurance taken/won, even money, side bets placed/won and net, strategy decisions
and accuracy, best by-the-book run, rebuys, peak bankroll and first-played time.
