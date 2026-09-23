# Audio

Every sound is synthesized by `tools/generate_audio.py` (numpy/scipy, fixed seeds, byte-identical output) and
encoded to Ogg Vorbis in `assets/audio/` (~3 MB). No samples or recordings are used.

| Group | Files | How it is made |
| --- | --- | --- |
| Cards | `card_slide_1–3`, `card_flip_1–2`, `card_place_1–2` | Band-passed noise swishes with felt friction and a soft tap; filtered snaps with paper flutter; muffled thuds |
| Chips | `chip_click_1–3`, `chip_stack_1–2`, `chips_payout` | Five inharmonic clay resonances (2–11 kHz) plus a knock and transient; randomized sequences |
| Shuffle | `shuffle` | ~57 accelerating card-edge clicks, a bridge whirr and squaring taps |
| Interface | `ui_hover`, `ui_click`, `ui_back` | Tiny woodblock clicks, 9–18 dB below the table |
| Results | `win`, `blackjack`, `lose`, `bust`, `push`, `insurance`, `achievement`, `coach_good`, `coach_bad` | Vibraphone, celesta and bell voices in F major through a small synthetic room |
| Music | `music_lounge` (87 s), `music_menu` (69 s) | FM electric piano, walking bass and brushes (32-bar AABA in F at 88 BPM); a slower nocturne in B♭ for menus |
| Ambience | `ambience_room` (48 s) | Room tone, heavily blurred crowd murmur and faint distant clinks |

Loops are rendered so that tails fold back onto the start, making the loop point seamless.

## Playback — `AudioManager`

- Effects play on the **FX** bus with a random variant and slight pitch jitter.
- Music plays on **Music** and crossfades between the menu and table tracks; ambience loops on **Ambient**.
- Master, Music, Effects and Ambience volumes and Mute are in Settings → Audio.
