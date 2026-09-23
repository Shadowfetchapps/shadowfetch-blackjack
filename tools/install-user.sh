#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_SRC="$ROOT/export/linux/shadowfetch-blackjack.x86_64"
if [[ ! -x "$BIN_SRC" ]]; then
  echo "Exporting Linux release…"
  "$ROOT/tools/export_linux.sh"
fi
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
BINDIR="$HOME/.local/bin"
APP_ID="com.shadowfetch.Blackjack"
ICON_NAME="shadowfetch-blackjack"
mkdir -p "$BINDIR" "$PREFIX/applications"
install -m 0755 "$BIN_SRC" "$BINDIR/shadowfetch-blackjack"
if [[ -f "$ROOT/export/linux/shadowfetch-blackjack.pck" ]]; then
  install -m 0644 "$ROOT/export/linux/shadowfetch-blackjack.pck" "$BINDIR/shadowfetch-blackjack.pck"
fi
# Release tarballs ship the PNG icons; only rebuild them (needs rsvg-convert) when missing.
if [[ ! -f "$ROOT/data/icons/hicolor/256x256/apps/${ICON_NAME}.png" ]]; then
  "$ROOT/tools/generate-icons.sh"
fi
if [[ -f "$ROOT/VERSION" ]]; then
  VERSION="$(<"$ROOT/VERSION")"
else
  VERSION="$(grep -Po '(?<=config/version=")[^"]+' "$ROOT/project.godot")"
fi
for size in 16 22 24 32 48 64 96 128 256 512 1024; do
  dest="$PREFIX/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dest"
  install -m 0644 "$ROOT/data/icons/hicolor/${size}x${size}/apps/${ICON_NAME}.png" "$dest/${ICON_NAME}.png"
done
mkdir -p "$PREFIX/icons/hicolor/scalable/apps"
install -m 0644 "$ROOT/icon.svg" "$PREFIX/icons/hicolor/scalable/apps/${ICON_NAME}.svg"
cat > "$PREFIX/applications/${APP_ID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Shadowfetch Blackjack
GenericName=Blackjack
Comment=Flagship 3D blackjack for Linux. Fictional chips only.
Exec=${BINDIR}/shadowfetch-blackjack
TryExec=${BINDIR}/shadowfetch-blackjack
Icon=${ICON_NAME}
Terminal=false
Categories=Game;CardGame;
Keywords=blackjack;cards;casino;shadowfetch;
StartupNotify=true
StartupWMClass=Shadowfetch Blackjack
X-AppVersion=${VERSION}
EOF
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$PREFIX/applications" || true
fi
if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f -t "$PREFIX/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$PREFIX/applications/${APP_ID}.desktop"
fi
test -x "$BINDIR/shadowfetch-blackjack"
echo "Installed Shadowfetch Blackjack ${VERSION} to $BINDIR/shadowfetch-blackjack"
echo "Desktop: $PREFIX/applications/${APP_ID}.desktop"
