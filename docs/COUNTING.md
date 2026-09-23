# Card counting trainer

Enable **Settings → Gameplay → Card counting trainer** to show the count under the shoe gauge.

- **Running count (Hi-Lo):** 2–6 count +1, 7–9 count 0, tens and aces count −1. Only cards you have actually seen
  are counted: the dealer's hole card is added when it is turned over.
- **True count:** running count ÷ decks remaining in the shoe (never less than half a deck). It turns green at
  +2 or above and red at −2 or below.
- The count resets whenever the shoe is shuffled (including the mid-round discard reshuffle).

The trainer is for practice: the game never changes its shuffle or odds based on your bets, and there is no
advantage-play detection. A full shoe of Hi-Lo tags sums to zero; the tests check this, the hole-card rule and the
true-count scaling.
