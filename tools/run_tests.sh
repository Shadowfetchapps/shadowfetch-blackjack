#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/.local/bin/godot}"
export SHADOWFETCH_BJ_HOME="${SHADOWFETCH_BJ_HOME:-/tmp/shadowfetch-blackjack-tests}"
rm -rf "$SHADOWFETCH_BJ_HOME"
mkdir -p "$SHADOWFETCH_BJ_HOME"
exec "$GODOT" --headless --path "$ROOT" --script res://tests/test_runner.gd
