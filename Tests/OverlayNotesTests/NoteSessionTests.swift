import Foundation
import Testing
@testable import OverlayNotes

@MainActor
struct NoteSessionTests {
    @Test
    func enablingClickThroughAlsoLocksOverlay() {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = OverlaySettingsStore(baseDirectory: baseDirectory)
        let session = NoteSession(initialText: "", fileURL: nil, settingsStore: store)

        session.setClickThrough(true)

        #expect(session.overlayPlacement.isClickThrough)
        #expect(session.overlayPlacement.isLocked)

        session.setClickThrough(false)

        #expect(session.overlayPlacement.isClickThrough == false)
        #expect(session.overlayPlacement.isLocked == false)
    }

    @Test
    func restoringClickThroughSettingsNormalizesLockState() throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = OverlaySettingsStore(baseDirectory: baseDirectory)
        let fileURL = baseDirectory.appendingPathComponent("meeting-notes.md")
        let identifier = store.stableIdentifier(for: fileURL)

        var settings = OverlaySettings()
        settings.placement.isClickThrough = true
        settings.placement.isLocked = false
        try store.save(settings, forIdentifier: identifier)

        let session = NoteSession(initialText: "", fileURL: fileURL, settingsStore: store)

        #expect(session.overlayPlacement.isClickThrough)
        #expect(session.overlayPlacement.isLocked)
    }

    @Test
    func openingFileWithoutExistingSettingsPersistsDefaults() async throws {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = OverlaySettingsStore(baseDirectory: baseDirectory)
        let fileURL = baseDirectory.appendingPathComponent("demo-notes.md")

        let session = NoteSession(initialText: "# Demo", fileURL: fileURL, settingsStore: store)

        #expect(session.fileURL == fileURL)

        var loaded: OverlaySettings?
        for _ in 0..<10 {
            loaded = store.load(for: fileURL)
            if loaded != nil {
                break
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(loaded != nil)
        #expect(loaded?.noteViewMode == .edit)
        #expect(loaded?.isScrollSyncEnabled == false)
    }
}
