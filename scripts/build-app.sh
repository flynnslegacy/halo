#!/bin/zsh
# Builds Menulens.app (release) into ./build and optionally installs it in /Applications.
# Usage: scripts/build-app.sh [--install]
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD="$ROOT/build"
APP="$BUILD/Menulens.app"

cd "$ROOT"
swift build -c release --product Menulens
BIN="$(swift build -c release --show-bin-path)/Menulens"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Menulens"
cp "$ROOT/config/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# App icon, rendered by the app itself.
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
"$BIN" --export-iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# Ad-hoc signature so macOS keeps permissions (Location, Bluetooth) between launches.
codesign --force --deep --sign - --identifier local.menulens.menubar "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Menulens 2>/dev/null || true
  rm -rf /Applications/Menulens.app
  cp -R "$APP" /Applications/Menulens.app
  echo "Installed /Applications/Menulens.app"
  open /Applications/Menulens.app
fi
