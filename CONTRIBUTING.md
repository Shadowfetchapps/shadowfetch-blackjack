# Contributing

Thanks for helping improve Shadowfetch Blackjack.

## Setup

- [Godot 4.7.2](https://godotengine.org/) on Linux x86_64 (`godot` on your `PATH`, or set `GODOT=/path/to/godot`).
- Optional, only for regenerating assets: Python 3 with Pillow, numpy and scipy, `ffmpeg` with libvorbis, and
  `rsvg-convert`.

```bash
./tools/run_tests.sh      # must be green before you open a pull request
godot --path .            # run the game
```

`SHADOWFETCH_BJ_HOME=/tmp/bj godot --path .` keeps your development runs away from your real saves.

## Conventions

- **Rules live in `scripts/engine/`** and stay free of nodes, tweens and autoloads so they can be unit-tested
  headless. Presentation reacts to engine state; it never changes money or cards.
- Money is integer cents. Every engine call returns `{ ok, action, reason?, phase }` and illegal calls change nothing.
- GDScript: static types where practical (the project treats untyped `:=` inference from a Variant as an error),
  tabs for indentation, `##` doc comments on classes and public functions.
- New gameplay rules need unit tests in `tests/test_features.gd` and should keep the simulation's invariants green.
- Assets must be original and reproducible: change the generator in `tools/`, re-run it, and commit its output.
  Fonts must be OFL or similarly permissive and listed in `assets/fonts/README.md`.
- Update the relevant page in `docs/` and add a line to `CHANGELOG.md`.

## Visual changes

Capture before/after screenshots with the QA harness (see [docs/TESTS.md](docs/TESTS.md#visual-qa)) and include
them in the pull request.

## Scope

Shadowfetch Blackjack is a play-money game. Contributions that add real-money wagering, payments, cash-out or
gambling-service integrations will not be accepted.
