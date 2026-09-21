# Engine

`BlackjackEngine` is a `RefCounted` rules object. It has no nodes, no Tweens, and no knowledge of the camera or HUD.

## Phases

`BETTING → (INSURANCE) → PLAYER → DEALER → SETTLE → BETTING`

- **BETTING** — chips, undo, clear, rebet, repeat, deal
- **INSURANCE** — only if the dealer upcard is an Ace
- **PLAYER** — hit / stand / double / split / optional late surrender on the active hand
- **DEALER** — draws below 17; S17 is default and H17 is configurable
- **SETTLE** — integer-cent payouts applied; `finish_round()` discards and returns to betting

## Public API

Every mutating call returns `{ ok, action, reason?, phase }`. Illegal actions are rejected and do not change money or cards.

- `add_chip`, `undo_chip`, `clear_bet`, `rebet`, `repeat_and_deal`, `deal`
- `take_insurance(accept)`
- `hit`, `stand`, `double_down`, `split`, `surrender`
- `legal_actions()`, `can(action)`
- `snapshot()` for debugging

## Scoring

`BJHand.best_total()` counts at most one ace as 11 when it does not bust. Soft 17 is ace+6. Natural blackjack is two cards totaling 21 that did **not** come from a split.

## Dealer

`dealer_should_hit()` is `best_total() < 17` under the default S17 rule. With H17 enabled it also hits a soft 17. If every player hand is bust or surrendered, the dealer does not draw.

## Payouts (cents)

| Result | Bankroll credit |
| --- | --- |
| Lose / bust | 0 |
| Late surrender | half the original bet |
| Push | original bet |
| Win | `2 * bet` |
| Blackjack | `bet + bet * 3 / 2` |
| Insurance win | `3 * insurance` (2:1 plus stake) |

The wager is deducted at deal / split / double / insurance. Settlement only credits returns.
