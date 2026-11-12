#!/bin/zsh
# Builds the Mac App Store edition of Menulens (sandboxed, -D APPSTORE) with Xcode.
# Usage: scripts/build-appstore.sh            archive + export a signed package in build/AppStore
#        scripts/build-appstore.sh --upload   archive + upload to App Store Connect
# Needs Xcode signed in to the developer account (team GF9ZH4NVU5) and XcodeGen.
set -euo pipefail

ROOT="${0:A:h:h}"
STORE="$ROOT/config/AppStore"
OUT="$ROOT/build/AppStore"
cd "$ROOT"

# App icon asset catalog, rendered by the app itself.
swift build --product Menulens
BIN="$(swift build --show-bin-path)/Menulens"
ICONSET="$OUT/AppIcon.iconset"
APPICON="$STORE/Assets.xcassets/AppIcon.appiconset"
rm -rf "$ICONSET" "$STORE/Assets.xcassets"
mkdir -p "$OUT" "$APPICON"
"$BIN" --export-iconset "$ICONSET"
cp "$ICONSET"/*.png "$APPICON/"
printf '{"info":{"author":"xcode","version":1}}\n' > "$STORE/Assets.xcassets/Contents.json"
python3 -I - "$APPICON" <<'PY'
import json, sys
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
        images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": name})
json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, open(sys.argv[1] + "/Contents.json", "w"), indent=2)
PY

xcodegen generate --spec "$STORE/project.yml" --quiet

ARCHIVE="$OUT/Menulens.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild -project "$STORE/Menulens.xcodeproj" -scheme MenulensAppStore -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates archive | tail -3

DESTINATION=export
[[ "${1:-}" == "--upload" ]] && DESTINATION=upload
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DESTINATION</string>
  <key>teamID</key><string>GF9ZH4NVU5</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" -allowProvisioningUpdates | tail -3
echo "Done: $OUT/export"
