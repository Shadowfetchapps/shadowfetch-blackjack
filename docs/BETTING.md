# Betting

Internal unit: **integer cents**. $10,000.00 start = `1_000_000`.

## Chips

| Label | Cents |
| --- | --- |
| $1 | 100 |
| $5 | 500 |
| $25 | 2_500 |
| $100 | 10_000 |
| $500 | 50_000 |
| $1_000 | 100_000 |

A chip is rejected if it would make the pending bet exceed bankroll. Undo pops the last chip. Clear empties the stack. Rebet rebuilds the previous wager with a greedy breakdown. Repeat is rebet + deal.

## Split and double

Each extra hand or double deducts another copy of that hand's current bet. Split aces cannot double. DAS is allowed on non-ace splits.

## Insurance

Cost is `bet / 2` from the **original** bet (first hand). Rejected if the bankroll cannot cover it.
