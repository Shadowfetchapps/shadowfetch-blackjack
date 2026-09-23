# Rules

Shadowfetch Blackjack plays American-style blackjack with a hole card and dealer peek. All chips are fictional.

## The hand

- Cards 2–10 count their number, J/Q/K count 10, aces count 1 or 11 (at most one ace counts 11).
- A **blackjack** (natural) is an ace plus a ten-value card as the first two cards of an unsplit hand.
- You and the dealer each get two cards; the dealer's first card (the hole card) is face down.
- If the dealer shows an **ace or a ten**, the dealer **peeks**. A dealer blackjack ends the round at once: you lose
  only your original bet (or push with your own blackjack).
- Twenty-one stands automatically. A bust loses immediately, even if the dealer later busts.

## Player options

| Option | When | Effect |
| --- | --- | --- |
| Hit | Any live hand below 21 (not split aces) | Take a card |
| Stand | Any live hand | Keep the total |
| Double | First two cards of a hand (after a split only with DAS) | Double the bet, take exactly one card |
| Split | Two cards of the same **rank** (10–K do not pair), under the hand limit | Two hands, each with the original bet |
| Surrender | First two cards, unsplit hand, late surrender on | Forfeit half the bet |
| Insurance | Dealer shows an ace | Side wager of half the bet, pays 2:1 on a dealer blackjack |
| Even money | You hold a blackjack and the dealer shows an ace | Take a guaranteed 1:1 instead of risking a push |

Split hands receive their second card when you start playing them. Split aces receive one card each and stand
(unless re-splitting aces is allowed and another ace arrives). A 21 on a split hand is not a blackjack.

## Dealer

The dealer draws to 17. On **S17** tables the dealer stands on soft 17 (A-6); on **H17** tables the dealer hits it.
If every player hand busted or surrendered, the dealer does not draw (the hole card is still turned over).

## Payouts

| Result | Returned to you (bet + winnings) |
| --- | --- |
| Blackjack 3:2 | 2.5 × bet |
| Blackjack 6:5 | 2.2 × bet |
| Win / even money | 2 × bet |
| Push | 1 × bet |
| Surrender | 0.5 × bet |
| Loss / bust | 0 |
| Insurance win | 3 × insurance stake |

Everything is integer cents; fractions of a cent round down (e.g. 3:2 on $1 returns $2.50, 6:5 on $5 returns $11).

## Table rules

Open **Table Rules** from the main or pause menu. Changes are saved immediately and take effect on the next deal;
changing the deck count or penetration brings a fresh shoe.

| Rule | Options | Default |
| --- | --- | --- |
| Decks | 1, 2, 4, 6, 8 | 6 |
| Dealer soft 17 | Stands (S17) / Hits (H17) | S17 |
| Blackjack pays | 3:2 / 6:5 | 3:2 |
| Split up to | 2, 3, 4 hands | 4 |
| Double after split | on / off | on |
| Re-split aces | on / off | off |
| Late surrender | on / off | on |
| Penetration | 60–85 % | 75 % |
| Side bets | on / off | on |

Presets: **Vegas Strip** (the defaults), **Downtown Double Deck** (2D H17, no surrender, 70 %),
**Atlantic Eight Deck** (8D S17 RSA, 80 %) and **Single Deck 6:5** (1D H17 6:5, split to 2, no DAS, 65 %).

The rules page shows an estimated house edge for the main bet under perfect basic strategy, built from the widely
published rule-effect figures (baseline 8D S17 no-DAS 0.57 %; decks −0.48/−0.19/−0.06/−0.02/0; H17 +0.22;
DAS −0.14; RSA −0.08; late surrender −0.08; 6:5 +1.39; split to 2/3 hands +0.05/+0.01). The default table comes out
at about 0.33 %; a 1,000,000-hand simulation of the built-in strategy agrees within its error bars
(see [TESTS.md](TESTS.md)).

## Limits and bankroll

- Main bet $1–$10,000; each side bet up to $1,000. Chips: $1, $5, $25, $100, $500, $1,000.
- Your bankroll starts at $10,000 and persists between sessions. **Restart Session** refills it without erasing
  lifetime statistics; when you run out, the house offers a fresh $10,000 **rebuy**.
- Quitting in the middle of a hand voids that hand: the next launch resumes with the bankroll from before the deal.

Side bets are described in [SIDE_BETS.md](SIDE_BETS.md).
