# Tests

```bash
./tools/run_tests.sh
```

Headless Godot loads `tests/test_runner.gd` → `TestBlackjackEngine`.

Coverage includes: card values, soft/hard/multi-ace, shoe uniqueness and cut-card reshuffle, deal totals, 3:2 blackjack, two-sided blackjack push, ordinary push, bust (dealer does not draw), double, split, split aces (not blackjack), resplit / max four hands, insurance win and lose, default S17, optional H17, late-surrender legality and payout, dealer hits 16, bankroll bounds, illegal actions, rapid extra input, integer payouts, clean new rounds, conservation across reshuffles, save/load, corrupt recovery, and **200,000** simulated hands with basic-strategy-plus-noise play.

Simulation invariants: non-negative bankroll, unique 312-card shoe, conserved card count, payout table match (including surrender), legal randomized actions only, and return to betting after each hand.
