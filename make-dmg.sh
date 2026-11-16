#!/bin/zsh
# Builds the app, then packs it into outputs/PinToTop.dmg with an
# Applications shortcut so users can drag it in.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/outputs/Pin To Top.app"
DMG="$ROOT/outputs/PinToTop.dmg"
STAGING="$ROOT/work/dmg"

"$ROOT/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Pin To Top $VERSION" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov "$DMG" >/dev/null
rm -rf "$STAGING"

echo "DMG: $DMG"
shasum -a 256 "$DMG"
