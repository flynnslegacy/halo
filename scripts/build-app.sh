#!/bin/zsh
# Builds Halo.app (release) into ./build and optionally installs it in /Applications.
# Usage: scripts/build-app.sh [--install]
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD="$ROOT/build"
APP="$BUILD/Halo.app"

cd "$ROOT"
swift build -c release --product Halo
BIN="$(swift build -c release --show-bin-path)/Halo"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Halo"
cp "$ROOT/config/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# App icon, rendered by the app itself.
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
"$BIN" --export-iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Ad-hoc signature so macOS keeps permissions (Location, Bluetooth) between launches.
codesign --force --deep --sign - --identifier local.halo.menubar "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Halo 2>/dev/null || true
  rm -rf /Applications/Halo.app
  cp -R "$APP" /Applications/Halo.app
  echo "Installed /Applications/Halo.app"
  open /Applications/Halo.app
fi
