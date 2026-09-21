#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin/shadowfetch-blackjack"
DESKTOP="$DATA_HOME/applications/com.shadowfetch.Blackjack.desktop"
ICON_NAME="shadowfetch-blackjack"

rm -f "$BIN" "$HOME/.local/bin/shadowfetch-blackjack.pck" "$DESKTOP"
for size in 16 22 24 32 48 64 96 128 256 512 1024; do
  rm -f "$DATA_HOME/icons/hicolor/${size}x${size}/apps/${ICON_NAME}.png"
done
rm -f "$DATA_HOME/icons/hicolor/scalable/apps/${ICON_NAME}.svg"

if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$DATA_HOME/applications" || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" >/dev/null 2>&1 || true
fi

echo "Removed Shadowfetch Blackjack application files."
echo "Settings and statistics were preserved."
