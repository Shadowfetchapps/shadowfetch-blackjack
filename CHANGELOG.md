# Changelog

## 2.0.0

- Reframed the table as a deeper green, black, and gold Shadowfetch private-table environment with branded architecture, tighter camera composition, ACES lighting, and restrained quality-tier bloom.
- Enlarged cards and moved both player and dealer layouts into the seated camera's strongest readable area while retaining a face-down dealer hole card.
- Added optional late surrender and configurable H17 play; S17 remains the default. Both rules are persisted and lock in on the next deal.
- Added surrender UI, keyboard control, settlement feedback, statistics accounting, and randomized-simulation coverage.
- Sequenced action presentation so hit/double/split/dealer cards finish arriving before result reveal and cleanup.
- Completed settings control synchronization and grouped table rules in the settings screen.
- Added a reproducible versioned Linux tarball/checksum packager and a user-local uninstall path that preserves saves.
- Expanded the full suite to 172 assertions and 200,000 complete randomized hands.

## 1.0.0

- Standalone Linux 3D blackjack with seated first-person camera
- Readable tilted card faces (player hands and dealer up-card); hole card stays down until reveal
- Six-deck shoe, S17, 3:2 blackjack, DAS, split to four hands, conventional split aces, insurance
- Fictional bankroll, persisted stats and settings
- User-local install: `~/.local/bin/shadowfetch-blackjack`
