# Shoe

`BJShoe` models an n-deck shoe (1, 2, 4, 6 or 8 decks; 52 × n cards). Each card carries an integer
`uid = deck × 52 + suit × 13 + (rank − 1)` so bookkeeping is O(1).

## Shuffle and cut card

A full shuffle is Fisher–Yates over all cards using `RandomNumberGenerator` (seedable for tests). The cut card is
placed at `penetration × capacity ± 6` cards (clamped to at least half the shoe and at least 12 from the end).
When the draw count reaches it, `cut_reached` is set; the current round finishes and the next `deal()` reshuffles.
A new round is also never started with fewer than 20 cards left.

## Conservation

Every card is always in exactly one place: the live draw stack, the discard tray, or in play on the table.

```
remaining + discarded + in_play == capacity      and every uid appears exactly once
```

`unique_ok()` verifies both in O(n) with a byte map. The simulation checks it after every one of 200,000 rounds.

## Mid-round exhaustion

If the live stack runs dry during a round (possible with one deck and many splits), only the **discard tray** is
shuffled back in — the cards on the table stay put — and a full reshuffle is forced before the next round.

## Signals and helpers

- `reshuffled(full)` — the engine resets the Hi-Lo count and the controller plays the shuffle presentation.
- `dealt_fraction()` / `cut_fraction()` drive the HUD shoe gauge; `decks_remaining()` feeds the true count.
- `force_next(cards)` (tests and QA only) moves specific cards to the top of the draw stack.
