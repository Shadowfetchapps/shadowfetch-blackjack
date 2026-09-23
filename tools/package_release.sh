#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(grep -Po "(?<=config/version=\")[^\"]+" "$ROOT/project.godot")}"
NAME="shadowfetch-blackjack-${VERSION}-linux-x86_64"
STAGE="$ROOT/export/package/$NAME"
ARCHIVE="$ROOT/export/$NAME.tar.gz"

rm -rf "$ROOT/export/package"
"$ROOT/tools/export_linux.sh"
"$ROOT/tools/generate-icons.sh"
mkdir -p "$STAGE/export/linux" "$STAGE/tools"

install -m 0755 "$ROOT/export/linux/shadowfetch-blackjack.x86_64" "$STAGE/export/linux/"
install -m 0755 "$ROOT/tools/install-user.sh" "$ROOT/tools/uninstall-user.sh" "$ROOT/tools/generate-icons.sh" "$STAGE/tools/"
cp -a "$ROOT/data" "$STAGE/"
install -m 0644 "$ROOT/icon.svg" "$ROOT/LICENSE" "$ROOT/README.md" "$ROOT/CHANGELOG.md" "$STAGE/"

tar -C "$ROOT/export/package" -czf "$ARCHIVE" "$NAME"
(cd "$ROOT/export" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
echo "$ARCHIVE"
echo "$ARCHIVE.sha256"
