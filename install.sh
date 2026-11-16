#!/bin/zsh
# Installs the latest Pin To Top release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/Abhishek-programs/PinToTop/main/install.sh | zsh
#
# Files downloaded with curl aren't quarantined, so macOS doesn't show the
# "could not verify" dialog that a browser download of an unnotarized app gets.
set -euo pipefail

DMG_URL="https://github.com/Abhishek-programs/PinToTop/releases/latest/download/PinToTop.dmg"
APP_NAME="Pin To Top.app"
DEST="/Applications"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Pin To Top currently needs an Apple Silicon Mac." >&2
  exit 1
fi
if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
  echo "Pin To Top needs macOS 14 (Sonoma) or later." >&2
  exit 1
fi

TMP="$(mktemp -d)"
MOUNT=""
cleanup() {
  [[ -n "$MOUNT" ]] && hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Pin To Top..."
curl -fL --progress-bar -o "$TMP/PinToTop.dmg" "$DMG_URL"

MOUNT="$(hdiutil attach -nobrowse -readonly "$TMP/PinToTop.dmg" 2>/dev/null | tail -1 | cut -f3)"
if [[ ! -d "$MOUNT/$APP_NAME" ]]; then
  echo "Couldn't find $APP_NAME in the download." >&2
  exit 1
fi

if pgrep -x PinToTop >/dev/null; then
  echo "Quitting the running copy..."
  pkill -x PinToTop || true
  sleep 1
fi

echo "Installing to $DEST..."
rm -rf "$DEST/$APP_NAME"
ditto "$MOUNT/$APP_NAME" "$DEST/$APP_NAME"
xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

echo "Done. Opening Pin To Top (look for the pin in your menu bar)."
open "$DEST/$APP_NAME"
