#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/outputs/Pin To Top.app"
SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
mkdir -p "$ROOT/work/clang-cache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
sources=("${(@f)$(find "$ROOT/Sources/PinToTop" -name '*.swift' | sort)}")
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx14.0 \
  -module-cache-path "$ROOT/work/clang-cache" \
  "${sources[@]}" \
  -o "$APP/Contents/MacOS/PinToTop"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
if [[ ! -f "$ROOT/AppIcon.icns" ]]; then
  echo "Missing AppIcon.icns. Run work/make-icon.swift and iconutil first." >&2
  exit 1
fi
cp "$ROOT/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
  echo "Built with ad-hoc signing. Screen Recording authorization may need to be granted again after rebuilding."
else
  codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
