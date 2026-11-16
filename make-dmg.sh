#!/bin/zsh
# Builds the app, then packs it into outputs/PinToTop.dmg: app + Applications
# shortcut on a background that explains the first-launch "Open Anyway" step.
# The window layout is set through Finder, so the first run may ask to let
# Terminal control Finder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/outputs/Pin To Top.app"
DMG="$ROOT/outputs/PinToTop.dmg"
WORK="$ROOT/work/dmg"
RW_DMG="$WORK/rw.dmg"
BACKGROUND="$WORK/background.png"

"$ROOT/build-app.sh"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")"
VOLNAME="Pin To Top $VERSION"

rm -rf "$WORK" "$DMG"
mkdir -p "$WORK/stage/.background"
swift "$ROOT/work/make-dmg-background.swift" "$BACKGROUND" >/dev/null
cp -R "$APP" "$WORK/stage/"
cp "$BACKGROUND" "$WORK/stage/.background/background.png"
ln -s /Applications "$WORK/stage/Applications"

# Detach any stale mount with the same name, then build a writable image.
[[ -d "/Volumes/$VOLNAME" ]] && hdiutil detach "/Volumes/$VOLNAME" -quiet || true
hdiutil create -volname "$VOLNAME" -srcfolder "$WORK/stage" -fs HFS+ -format UDRW -ov "$RW_DMG" >/dev/null
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | tail -1 | cut -f3)"

osascript <<EOF
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 800, 548}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.png"
    set position of item "Pin To Top.app" of container window to {150, 175}
    set position of item "Applications" of container window to {450, 175}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$WORK"

echo "DMG: $DMG"
shasum -a 256 "$DMG"
