# Basic strategy and the coach

`BJStrategy` (`scripts/engine/bj_strategy.gd`) encodes basic strategy for the **active table rules**. The HINT
button, the coach, the strategy chart page and the edge check all use the same code.

## The chart

The chart is the standard total-dependent multi-deck strategy with these rule variations:

- **H17:** double 11 vs A, double soft 18 vs 2, double soft 19 vs 6, surrender 15/17 vs A, surrender 8-8 vs A.
- **Double after split:** splits 2-2/3-3 vs 2–3, 4-4 vs 5–6 and 6-6 vs 2 (otherwise play the total).
- **Late surrender:** surrender hard 16 vs 9/10/A and hard 15 vs 10 (plus the H17 additions above).
- **One or two decks:** double 11 vs A and 9 vs 2.

Chart codes: `H` hit · `S` stand · `D` double, else hit · `Ds` double, else stand · `P` split ·
`Rh`/`Rs`/`Rp` surrender, else hit / stand / split. `display_code()` folds codes the table makes irrelevant
(no surrender, DAS on/off) so the chart page shows exactly what to do at this table.

## Advice

`recommend(hand, upcard, rules, can_double, can_split, can_surrender)` resolves a code against what is legal right
now — e.g. a three-card soft 18 vs 4 is `Ds` → **stand**, and a pair of 8s at the split limit plays as hard 16.
Insurance and even money are always declined.

## Coach

Every decision is judged before it is applied (`BlackjackEngine.last_decision`) and tallied per round
(`round_record.decisions/correct`) and for life (strategy accuracy, best by-the-book run).

| Coach setting | Behaviour |
| --- | --- |
| Off | No HINT button; decisions are still tallied |
| Hints on request (default) | HINT (T) shows the play and pulses the right button |
| Coach every decision | Each action gets a ✓ or the basic-strategy alternative, with a soft sound |

## Validation

`tests/edge_check.gd` plays 1,000,000 rounds with `hint()` on the default rules. The measured player return,
**−0.338 % ± 0.114 %**, matches the published figure of about −0.33 % — strong evidence that both the strategy and
the payouts are right. Unit tests pin down dozens of individual chart cells.
