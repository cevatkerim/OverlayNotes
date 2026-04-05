import AppKit
import SwiftUI

@main
struct OverlayNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: NoteDocument()) { configuration in
            NoteDocumentScene(configuration: configuration)
        }

        Settings {
            AppInfoView()
                .frame(width: 480, height: 360)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct AppInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Overlay Notes")
                .font(.largeTitle.bold())

            Text("Use one Markdown document per conversation or presentation, then launch a separate floating overlay pane for each note.")
                .foregroundStyle(.secondary)

            GroupBox("Share Safety") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Window")
                        .font(.headline)
                    Text("Use this when you share a single app or window in Zoom or Teams. The overlay stays on the same display as the note window.")

                    Text("Second Display")
                        .font(.headline)
                        .padding(.top, 6)
                    Text("Use this with a second display. The overlay moves to the other display so your shared desktop stays clean.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            Text("This build uses only public macOS APIs and does not claim to defeat all screen-capture paths.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
