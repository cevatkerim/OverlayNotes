# OverlayNotes

OverlayNotes is a native macOS Markdown editor with a floating presenter overlay. It is designed for speaker notes, demos, and window-sharing workflows where you want a clean reading surface without losing an editable source document.

## Highlights

- Native macOS app built with SwiftUI and AppKit
- Markdown `Edit`, `Preview`, and `Split` modes
- Bundled `markdown-it` rendering with offline support
- Relative image rendering in preview for saved notes
- Optional synced scrolling in Split view
- Floating overlay window with `Read` and `Edit` modes
- Per-note overlay settings persisted outside the `.md` file
- Explicit sharing modes for same-window and second-display setups

## Sharing Model

OverlayNotes does not attempt to promise invisibility across every screen-capture path on macOS.

- `Window`: keeps the overlay on the same display as the note window and is intended for app or window sharing in tools like Zoom or Teams
- `Second Display`: moves the overlay to another display and is intended for desktop-sharing setups where the shared display is different from the display you read from

## Install

An unsigned drag-install DMG is included in the repository at:

```bash
Releases/OverlayNotes.dmg
```

Because this build is unsigned and not notarized, macOS may warn the first time it is opened. On a trusted machine, you can install it by dragging `OverlayNotes.app` into `Applications` and then opening it with the standard right-click `Open` flow if Gatekeeper blocks the first launch.

## Build

### Xcode

```bash
xcodebuild -project OverlayNotes.xcodeproj -scheme OverlayNotes -configuration Debug -derivedDataPath .xcode-derived build
```

Debug app output:

```bash
.xcode-derived/Build/Products/Debug/OverlayNotes.app
```

### Tests

```bash
swift test --disable-sandbox
```

### Legacy SwiftPM App Bundle

For quick local experiments there is also a lightweight bundle script:

```bash
./Scripts/build_app_bundle.sh
```

This is not the primary distribution path, but it can still assemble a local `.app` from the SwiftPM build output.

## Package An Unsigned DMG

```bash
./Scripts/package_unsigned_dmg.sh
```

Release DMG output:

```bash
Releases/OverlayNotes.dmg
```

## App Icons

Source icon assets live in:

```bash
Icons/
```

The checked-in Xcode app icon set in `App/Assets.xcassets/AppIcon.appiconset` is generated from those macOS sizes.

## Project Structure

- `App/`: macOS app bundle resources, asset catalog, and plist
- `Sources/Controllers`: note session coordination and overlay window control
- `Sources/Models`: markdown rendering and document state
- `Sources/Persistence`: per-note overlay settings storage
- `Sources/Support`: AppKit bridges for editor and preview behavior
- `Sources/Views`: SwiftUI scenes and editor UI
- `Scripts/`: local build and packaging helpers
- `Releases/`: distributable DMG artifacts intended for sharing
