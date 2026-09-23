# Tests

```bash
./tools/run_tests.sh                       # everything (~2 minutes)
SF_BJ_SIM_HANDS=0 ./tools/run_tests.sh     # skip the long simulation
SF_BJ_SMOKE=0 ./tools/run_tests.sh         # skip the game-scene smoke test
```

The runner refreshes Godot's import/class cache, runs the headless suites in `tests/`, then boots the real game
headless for a smoke test. Saves go to a scratch folder via `SHADOWFETCH_BJ_HOME`.

## Suites

| Suite | Covers |
| --- | --- |
| `test_engine.gd` | Card values and ids, soft/hard/multi-ace totals, shoe shuffle, cut card and conservation, deal, 3:2, two-sided blackjack, push, bust, double, split with realistic dealing, split aces, re-split and hand limits, insurance, S17/H17, late surrender, dealer draws, bankroll bounds and table limits, illegal and rapid input, integer payouts and formatting, clean new rounds, mid-round reshuffle, undo/remove/rebet across spots |
| `test_features.gd` | Rules model, validation, presets and house edge; rules → shoe; 6:5; no DAS; re-split aces; even money; Perfect Pairs and 21+3 (including exact single-deck category counts and the edge table); side-bet settlement and accounting; dozens of strategy chart cells; advice under constraints; coach judging; Hi-Lo count; round records |
| `test_persistence.gd` | Settings round trip, v1 and v2 migration, validation, corrupt-file recovery; stats round trip, v1 migration, round recording, history cap, corrupt recovery; achievements unlocks and persistence |
| `test_simulation.gd` | 200,000 hands across five rule sets with a basic-strategy player making 8 % random legal moves, random side bets and insurance |

The simulation asserts, for every round: money is conserved (bankroll change equals the reported net), the shoe
holds every card exactly once, payouts match the table for the outcome and rules, side bets match an independent
evaluation of the dealt cards, the hand limit holds, the bankroll never goes negative and no legal action is refused.

## Smoke test

`SF_BJ_QA=smoke` boots the full game headless (autoloads, table, HUD, menus, audio) and plays 12 hands through
the real `GameController` with basic strategy. The runner fails on any script error.

## Edge check (optional)

```bash
godot --headless --path . --script res://tests/edge_check.gd   # SF_BJ_EDGE_HANDS=1000000
```

Perfect basic strategy on the default rules over 1,000,000 rounds measured **−0.338 % ± 0.114 %**, in line with the
published ≈ −0.33 %.

## Visual QA

```bash
SHADOWFETCH_BJ_HOME=/tmp/qa SF_BJ_QA=shots SF_BJ_QA_OUTPUT=/tmp/shots godot --path .
```

replays a scripted session (menus, betting, a perfect pair, a split with the coach, a blackjack, insurance, the
overhead view and every page) and saves the screenshots used in the README.

## CI

`.github/workflows/ci.yml` downloads Godot 4.7.2 and runs the full suite (with a shorter simulation) on every push
and pull request.
