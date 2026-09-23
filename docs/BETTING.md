# Betting

Internal unit: **integer cents**. The starting bankroll of $10,000.00 is `1_000_000`.

## Spots and chips

There are three betting spots: `main`, `pp` (Perfect Pairs) and `t3` (21+3). Chips are $1, $5, $25, $100, $500 and
$1,000 (`100 … 100_000` cents).

- Clicking a chip in the rack (or pressing 1–6) selects it and adds it to the main bet.
- Clicking a betting circle on the felt places the selected chip on that spot; right-clicking removes the last chip
  placed on that spot.
- **Undo** removes the most recent chip on any spot; **Clear** empties every spot.

Wagers are only recorded while betting and are deducted at `deal()`. A chip is refused when it would exceed the
bankroll (`insufficient_bankroll`), the spot's limit (`table_max`: $10,000 main, $1,000 per side bet), or when side
bets are switched off (`side_bets_off`). A deal needs a main bet.

## Rebet and repeat

`rebet()` rebuilds the previous round's wagers with the fewest chips. Side bets come back only when they are enabled
and affordable together with the main bet; otherwise only the main bet is restored. **Repeat** (R / REBET & DEAL)
is rebet followed by deal.

## During the round

- **Split** and **double** each deduct another copy of that hand's bet. The doubled stack sits beside the original.
- **Insurance** costs half the original bet; **even money** costs nothing extra.
- Side bets settle straight after the deal.

## Broke

When the bankroll falls below $1 with nothing on the table, the house offers a $10,000 rebuy (`rebuy()`), counted in
statistics and rewarded with the *Fresh Stack* achievement.
