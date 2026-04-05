# Overlay Notes

Native macOS overlay notes app built with SwiftUI for the app UI and AppKit for the floating overlay windows.

## What It Does

- Opens and saves Markdown notes as plain `.md` files.
- Creates one independent floating overlay pane per note window.
- Supports `Edit`, `Preview`, and `Split` note views.
- Supports `Read` and `Edit` overlay modes.
- Persists overlay appearance and placement separately from the Markdown file.
- Provides two explicit share-safety modes:
  - `Window Share`: for sharing a single app or window.
  - `Desktop Safe`: for sharing a full desktop when a second, unshared display is available.

## Important Limitation

This app does **not** claim to make a visible same-display overlay universally invisible to all screen-capture paths on modern macOS. The product language and UI are intentionally explicit about that:

- `Window Share` is meant for Zoom/Teams window sharing.
- `Desktop Safe` is meant for dual-display workflows.

## Open In Xcode

Open [OverlayNotes.xcodeproj](/Users/kerimincedayi/Development/AI/ai-notes/OverlayNotes.xcodeproj) in Xcode and run the `OverlayNotes` scheme.

This is now the primary way to build and run the app. Running from the Xcode project gives you a normal macOS app bundle with a Dock icon and proper activation behavior.

## Build From Xcode

```bash
xcodebuild -project OverlayNotes.xcodeproj -scheme OverlayNotes -configuration Debug -derivedDataPath .xcode-derived build
```

The built app will be at:

```bash
.xcode-derived/Build/Products/Debug/OverlayNotes.app
```

## Build With SwiftPM

The Swift package is still present for lightweight command-line builds and tests, but it is no longer the recommended way to launch the app from Xcode.

```bash
swift build
```

## Test

```bash
swift test
```

## Run With SwiftPM

```bash
swift run OverlayNotes
```

## Repo Layout

- `Sources/Models`: document and overlay state types.
- `Sources/Controllers`: note session coordination and AppKit overlay window management.
- `Sources/Views`: editor and overlay SwiftUI views.
- `Sources/Persistence`: per-note overlay settings storage.
