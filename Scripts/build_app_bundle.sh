#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/Build"
APP_DIR="$BUILD_DIR/OverlayNotes.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"
APP_ICONSET_SOURCE="$ROOT_DIR/App/Assets.xcassets/AppIcon.appiconset"

export HOME="$ROOT_DIR/.codex-home"
export XDG_CACHE_HOME="$ROOT_DIR/.codex-cache"
export CLANG_MODULE_CACHE_PATH="/tmp/overlaynotes-clang-module-cache"

mkdir -p "$HOME" "$XDG_CACHE_HOME" "$CLANG_MODULE_CACHE_PATH" "$BUILD_DIR"

swift build --disable-sandbox

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -type f -name OverlayNotes -path '*/debug/OverlayNotes' | head -n 1)"
RESOURCE_BUNDLE_PATH="$(find "$ROOT_DIR/.build" -type d -name 'OverlayNotes_OverlayNotes.bundle' | head -n 1)"

if [[ -z "$EXECUTABLE_PATH" ]]; then
  echo "Could not find built executable." >&2
  exit 1
fi

if [[ -z "$RESOURCE_BUNDLE_PATH" ]]; then
  echo "Could not find SwiftPM resource bundle." >&2
  exit 1
fi

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$EXECUTABLE_PATH" "$MACOS_DIR/OverlayNotes"
chmod +x "$MACOS_DIR/OverlayNotes"
cp -R "$RESOURCE_BUNDLE_PATH" "$RESOURCES_DIR/"

cp "$APP_ICONSET_SOURCE/icon-16@1x.png" "$ICONSET_DIR/icon_16x16.png"
cp "$APP_ICONSET_SOURCE/icon-16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png"
cp "$APP_ICONSET_SOURCE/icon-32@1x.png" "$ICONSET_DIR/icon_32x32.png"
cp "$APP_ICONSET_SOURCE/icon-32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png"
cp "$APP_ICONSET_SOURCE/icon-128@1x.png" "$ICONSET_DIR/icon_128x128.png"
cp "$APP_ICONSET_SOURCE/icon-128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png"
cp "$APP_ICONSET_SOURCE/icon-256@1x.png" "$ICONSET_DIR/icon_256x256.png"
cp "$APP_ICONSET_SOURCE/icon-256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png"
cp "$APP_ICONSET_SOURCE/icon-512@1x.png" "$ICONSET_DIR/icon_512x512.png"
cp "$APP_ICONSET_SOURCE/icon-512@2x.png" "$ICONSET_DIR/icon_512x512@2x.png"

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>OverlayNotes</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.codex.overlaynotes</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Overlay Notes</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Built app bundle at: $APP_DIR"
