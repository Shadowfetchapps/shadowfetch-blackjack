# Shoe

`BJShoe` models a **six-deck** shoe (312 unique cards). Each card id is `deck-suit-rank`.

## Shuffle

Fisher–Yates using `RandomNumberGenerator`. Tests may pass a seed to `BlackjackEngine.new(seed)`.

## Cut card

After a shuffle the cut index is placed 60–78 cards from the end. When draws reach that index, `cut_reached` is set. The current hand finishes; the next `deal()` reshuffles if the cut was reached or fewer than 30 cards remain.

## Conservation

At every moment:

```
remaining + discarded + in_play == 312
```

and every id appears exactly once. `unique_ok()` checks both.

`force_next(cards)` is test-only: it pulls matching cards to the top of the draw stack so edge cases can be scripted.
