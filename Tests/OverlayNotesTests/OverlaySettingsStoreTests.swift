import Foundation
import Testing
@testable import OverlayNotes

struct OverlaySettingsStoreTests {
    @Test
    func stableIdentifierIsRepeatable() {
        let store = OverlaySettingsStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let url = URL(fileURLWithPath: "/tmp/example.md")

        #expect(store.stableIdentifier(for: url) == store.stableIdentifier(for: url))
    }

    @Test
    func savesAndLoadsSettings() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = OverlaySettingsStore(baseDirectory: baseDirectory)
        let identifier = "note-settings"
        var settings = OverlaySettings()
        settings.shareSafetyMode = .desktopSafe
        settings.overlayMode = .edit
        settings.isScrollSyncEnabled = true
        settings.isOverlayVisible = true
        settings.appearance.opacity = 0.55

        try store.save(settings, forIdentifier: identifier)
        let loaded = store.load(forIdentifier: identifier)

        #expect(loaded == settings)
    }

    @Test
    func loadsLegacySettingsWithoutScrollSyncFlag() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = OverlaySettingsStore(baseDirectory: baseDirectory)
        let identifier = "legacy-note-settings"
        let legacyJSON = """
        {
          "shareSafetyMode": "windowShare",
          "noteViewMode": "split",
          "overlayMode": "read",
          "isOverlayVisible": true,
          "appearance": {
            "opacity": 0.88,
            "tintColor": {
              "red": 0.11,
              "green": 0.12,
              "blue": 0.15,
              "alpha": 0.9
            },
            "blurMaterial": "hudWindow",
            "textScale": 1,
            "themeOverride": "system"
          },
          "placement": {
            "isLocked": false,
            "isClickThrough": false,
            "staysOnTop": true
          }
        }
        """

        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try Data(legacyJSON.utf8)
            .write(to: baseDirectory.appendingPathComponent(identifier).appendingPathExtension("json"))

        let loaded = store.load(forIdentifier: identifier)

        #expect(loaded?.noteViewMode == .split)
        #expect(loaded?.isScrollSyncEnabled == false)
    }
}
