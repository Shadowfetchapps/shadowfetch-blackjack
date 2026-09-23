# Engine

`BlackjackEngine` (`scripts/engine/blackjack_engine.gd`) is a `RefCounted` rules object with no nodes, tweens or
knowledge of the camera or HUD. It is exercised directly by the unit tests and the simulation.

## Phases

`BETTING → (INSURANCE) → PLAYER → (DEALER) → SETTLE → BETTING`

| Phase | Legal calls |
| --- | --- |
| BETTING | `add_chip`, `remove_chip`, `set_bet`, `undo_chip`, `clear_bet`, `rebet`, `repeat_and_deal`, `deal`, `set_rules`, `rebuy` |
| INSURANCE | `take_insurance(accept)` (even money when the player holds a natural) |
| PLAYER | `hit`, `stand`, `double_down`, `split`, `surrender` |
| SETTLE | `finish_round` |

Every mutating call returns `{ ok, action, reason?, phase }`. Illegal calls are rejected (`rejected` signal,
`last_reject`) and change nothing. `legal_actions()` / `can(action)` report what is allowed right now.

## Components

| Script | Responsibility |
| --- | --- |
| `bj_card.gd` | Card value, suit, Hi-Lo tag, `uid()` unique within the shoe, `seq` draw order |
| `bj_hand.gd` | Totals (soft/hard), blackjack, pair, finished state, `total_text()`, decision log (`actions`) |
| `bj_shoe.gd` | n-deck shoe, Fisher–Yates shuffle, cut card, conservation checks — see [SHOE.md](SHOE.md) |
| `bj_rules.gd` | Table rules, validation, presets, house-edge estimate, felt text |
| `bj_money.gd` | Integer cents, chip values, table limits, payouts, formatting |
| `bj_side_bets.gd` | Perfect Pairs and 21+3 evaluation and payouts — see [SIDE_BETS.md](SIDE_BETS.md) |
| `bj_strategy.gd` | Basic strategy for the active rules — see [STRATEGY.md](STRATEGY.md) |

## Round details

- `deal()` discards the previous round, reshuffles if the cut card was reached, deducts **all** pending wagers,
  deals player / dealer hole / player / dealer up, then resolves side bets (their payouts are credited at once).
- An ace up-card enters INSURANCE (flagging `even_money_offered` for a player natural). Otherwise, and after
  insurance, the dealer peeks: a dealer blackjack settles at once; a player natural settles at once.
- `split()` moves the second card into a new hand inserted after the active one. The active hand draws immediately;
  the new hand draws when `_advance_hand()` reaches it. Split aces draw one card each and stand unless
  `resplit_aces` allows another split of a fresh ace pair.
- When no hand is left to play, the dealer reveals the hole card and draws while `dealer_should_hit()`
  (below 17, or soft 17 under H17), unless every hand busted/surrendered/took even money.
- `_settle_round()` credits returns, updates session counters and streaks, and builds `round_record`.

## Round record

`round_record` is a plain dictionary consumed by `StatsStore.record_round()`, the history page and achievements:

```
{ round, time, rules, wagered, net, bankroll, bankroll_before, decisions, correct, running_count,
  insurance, insurance_payout, even_money,
  hands: [{ cards: ["KS","7H"], total, text, actions: "HS", bet, payout, net, outcome, doubled, split }],
  dealer: { cards, total, text },
  side: [{ kind: "pp"|"t3", stake, result, payout, net }] }
```

Outcomes are `win`, `blackjack`, `even_money`, `push`, `lose`, `bust` and `surrender`.

## Coach and count hooks

Every player decision (and the insurance decision) is compared with `BJStrategy.recommend()` *before* it is
applied and stored in `last_decision` (`action`, `recommended`, `correct`, `situation`). `hint()` returns the
recommendation without acting. `running_count` / `true_count()` follow every card the player has seen —
see [COUNTING.md](COUNTING.md).
