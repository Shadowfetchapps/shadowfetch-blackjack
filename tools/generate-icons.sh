#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/icon.svg"
for size in 16 22 24 32 48 64 96 128 256 512 1024; do
  dest="$ROOT/data/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dest"
  rsvg-convert -w "$size" -h "$size" "$SRC" -o "$dest/shadowfetch-blackjack.png"
done
mkdir -p "$ROOT/packaging"
cp "$SRC" "$ROOT/packaging/shadowfetch-blackjack.svg"
echo "Generated Linux icon sizes."
