# Side bets

Both side bets are optional, placed on their own circles before the deal (up to $1,000 each), and settled
immediately after the first four cards are dealt — before insurance, the dealer peek or any player decision.
They are independent of the main hand: a side bet can win while the main bet loses, and vice versa.
Switch them off in **Table Rules → Side bets**.

## Perfect Pairs — your first two cards

| Result | Example | Pays |
| --- | --- | --- |
| Perfect pair | Q♥ Q♥ (same rank and suit, different decks) | 25 : 1 |
| Coloured pair | Q♥ Q♦ (same rank and colour) | 12 : 1 |
| Mixed pair | Q♥ Q♠ (same rank, different colour) | 6 : 1 |

A 10 and a king are **not** a pair — ranks must match.

## 21+3 — your two cards plus the dealer's up-card, as a three-card poker hand

| Result | Example | Pays |
| --- | --- | --- |
| Suited trips | 8♦ 8♦ 8♦ | 100 : 1 |
| Straight flush | 9♠ 10♠ J♠ | 40 : 1 |
| Three of a kind | 8♦ 8♠ 8♣ | 30 : 1 |
| Straight | 9♠ 10♥ J♠ | 10 : 1 |
| Flush | 2♣ 9♣ K♣ | 5 : 1 |

Aces play high or low (A-2-3 and Q-K-A are straights); K-A-2 does not wrap. Only the best result pays.

## House edge

Computed exactly (combinatorics over the whole shoe, not simulation) by `tools/side_bet_edges.py` and stored in
`BJSideBets.HOUSE_EDGE`. The Table Rules page shows the figures for the selected deck count.

| Decks | Perfect Pairs | 21+3 |
| --- | --- | --- |
| 1 | 47.06 % | 18.21 % |
| 2 | 22.33 % | 11.17 % |
| 4 | 10.14 % | 6.39 % |
| 6 | 6.11 % | 4.62 % |
| 8 | 4.10 % | 3.70 % |

With one deck a perfect pair is impossible, which is why Perfect Pairs is so expensive there. Compare these with the
main game's ~0.3–0.6 %: side bets are entertainment, not value.

The unit tests confirm the 21+3 classifier against the exact single-deck category counts (48 straight flushes,
52 trips, 720 straights and 1,096 flushes among 22,100 hands) and check the Perfect Pairs table against its
closed form; the simulation re-evaluates every side bet it places.
