#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
RELEASES_DIR="$ROOT_DIR/Releases"
DERIVED_DATA_DIR="$ROOT_DIR/.xcode-derived"
CONFIGURATION="Release"
APP_DIR="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/OverlayNotes.app"
DMG_ROOT="$BUILD_DIR/OverlayNotes-dmg-root"
DMG_PATH="$RELEASES_DIR/OverlayNotes.dmg"
VOLUME_NAME="OverlayNotes"

xcodebuild \
  -project "$ROOT_DIR/OverlayNotes.xcodeproj" \
  -scheme OverlayNotes \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
mkdir -p "$RELEASES_DIR"

ditto "$APP_DIR" "$DMG_ROOT/OverlayNotes.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created DMG at: $DMG_PATH"
