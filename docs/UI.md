# Interface

All interface code lives in `scripts/ui/`. `ThemeFactory` builds one shared `Theme` (black glass panels, gold
accents, ivory type) with the bundled fonts from `BJFonts`: Inter for interface text, Noto Serif Display for
headings, and Noto Sans Symbols 2 as a fallback for card suits.

## HUD — `hud.gd`

| Area | Contents |
| --- | --- |
| Top left | Bankroll (animated count), session result, hands, win rate |
| Top centre | Active rules, the current prompt, toasts; the result banner appears below |
| Top right | Strategy chart and menu buttons; shoe gauge with the cut card; optional Hi-Lo count; achievement toasts |
| Bottom left | Chip rack with key hints; the selected chip is ringed |
| Bottom centre | Context action bar: betting · insurance · player turn · next hand. Each button shows its key |
| Bottom right | Everything on the table: per-spot / per-hand amounts, side-bet results, last round |
| On the table | Hand badges projected from 3D: totals, bets, and WIN / LOSE / PUSH / BLACKJACK after the round |

HUD buttons never take keyboard focus, so Space always deals rather than re-pressing a clicked chip.

## Menus — `overlay_ui.gd` and `pages/`

A page stack with Esc / gamepad B to go back: main menu (over the orbiting table), pause, settings (Display, Audio,
Gameplay, Appearance, Accessibility — all applied live and saved), table rules, strategy chart, statistics, hand
history, achievements, how to play, confirmation dialogs and the rebuy dialog. Menus are fully keyboard- and
gamepad-navigable.

## First-run tour

Six coach-mark steps spotlight the chip rack, the side-bet circles, the action bar, the hint and the menu. It can be
replayed from Settings → Gameplay.

## Accessibility

- Interface scale 80–150 %.
- Four-colour deck (diamonds blue, clubs green).
- Reduce motion (no sway, parallax, push-ins, lamp flashes or menu orbit) and a separate camera-sway toggle.
- Every action has a keyboard shortcut and a gamepad button; hand totals can be hidden or shown.
