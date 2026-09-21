# Session state

`GameController` owns one `BlackjackEngine` and the 3D / HUD presentation.

1. Player builds `current_bet_cents` with chips (not yet deducted).
2. `deal()` deducts the bet, draws two cards each, and may enter insurance.
3. After insurance (or if no Ace), peek for dealer blackjack. Player natural blackjack settles immediately if the dealer does not have one.
4. Each player hand is played left to right. Twenty-one auto-stands. Bust ends the hand.
5. If any hand is live, the dealer plays to the S17 rule.
6. Settlement writes outcomes, updates stats, plays VFX, then `finish_round()` clears the table.

The player stays seated. Esc opens pause; Restart Session restores a $10,000 fictional bankroll without wiping lifetime totals unless the player resets stats.
