# Presentation

Everything visual is built at runtime from code and the original assets in `assets/`. The table never decides game
state: `GameController` asks `TableView` to mirror the engine, and each call returns how long its animation takes so
the controller can `await` it and sequence the round.

## World layout

`TableLayout` holds every position in metres (Y up, player on +Z facing the dealer on −Z): the half-disc felt
(radius 1.06 m), the rail, the three betting spots, card slots for up to four player hands, dealer cards, the shoe,
discard holder, chip rack and the player's rail point where chips come from and go to.

## Geometry — `TableBuilder`, `MeshKit`

- **Felt:** a half-disc mesh whose UVs map the printed layout; a custom shader (`assets/shaders/felt.gdshader`) adds
  tiled fibre noise and a velvet sheen.
- **Rail:** a superellipse profile swept along the arc (padded leather), a brass bead and a wood apron.
- **Cards:** one shared rounded-rectangle mesh (face, back and edge surfaces); per-card materials come from
  `CardTextures` (classic / four-colour, four backs) and are shared between cards.
- **Chips:** a shared cylinder mesh with planar face UVs and a wrapped edge band; `ChipStack` builds neat stacks
  (largest at the bottom, a second column past 14 chips) with drop-in and slide animations.
- **Room:** carpet, wainscoting and wallpaper, a lit sign, framed art, sconces, a credenza with lamps, a back bar
  and velvet curtains; a pendant lamp is the key light.

## Baked textures — `FeltPainter`, `PatternPainter`, `TextureBaker`

2D painters draw into an offscreen `SubViewport`; `TextureBaker` reads the image back, generates mipmaps and returns
a static texture (viewport textures have no mipmaps and shimmer at grazing angles). The felt is re-baked whenever
the rules or felt colour change: arc text for “Blackjack pays 3 to 2 / 6 to 5”, the S17/H17 line, the insurance
band, betting and side-bet circles and the empty seats. Carpet, wallpaper, art, the sign and the limits placard
are baked once. In headless runs baking is skipped.

## Choreography

| Moment | What happens |
| --- | --- |
| Betting | Chips drop onto the circles; available circles glow; hovered circles brighten |
| Deal | Cards slide from the shoe in draw order, flipping in flight; the hole card stays down |
| Side bets | Winners are paid from the rack and swept to the player; losers go to the rack |
| Peek | Under an ace or ten the dealer lifts the hole card's corner |
| Split | The second card slides across to its new hand; stacks re-space |
| Double | The extra card lands sideways; a matching stack joins the bet |
| Dealer | The hole card flips, then each draw lands with a pause |
| Settle | Winnings come from the rack, pushes return, losses are collected; badges and banner report the result |
| Clear | Cards are swept, face down, into the discard holder, which grows as the shoe is used |

Durations scale with **Dealing speed**. `sync_cards()` reconciles by card `uid`, so the same call covers deals,
hits, splits, flips and dealer draws.

## Camera — `CameraRig`

Seated and overhead poses (toggle with C), and a slow orbit behind the menus, blended smoothly. Optional breathing
sway and mouse parallax, a gentle pan toward the active split hand and an FOV push for blackjacks. Reduce motion
disables all of it.

## Lighting and quality

ACES tonemapping, glow for emissive lamps, a soft-shadowed pendant spotlight, a camera-side card fill and warm room
practicals.

| Quality | Adds |
| --- | --- |
| Low | Shadows 1024, no bloom |
| Medium | Bloom, 2048 shadows |
| High | SSAO, depth of field, 4096 shadows, 4K felt print |
| Ultra | SSIL, volumetric light, 8192 shadows |

MSAA (off/2×/4×/8×) handles 3D anti-aliasing; screen-space AA is off so interface text stays sharp.
