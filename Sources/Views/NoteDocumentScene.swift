import SwiftUI

struct NoteDocumentScene: View {
    @Binding private var document: NoteDocument
    private let fileURL: URL?
    @StateObject private var session: NoteSession

    init(configuration: FileDocumentConfiguration<NoteDocument>) {
        _document = configuration.$document
        fileURL = configuration.fileURL
        _session = StateObject(
            wrappedValue: NoteSession(
                initialText: configuration.document.text,
                fileURL: configuration.fileURL
            )
        )
    }

    var body: some View {
        NoteEditorView(session: session)
            .preferredColorScheme(session.overlayAppearance.themeOverride.colorScheme)
            .background(
                EditorWindowReader { window in
                    session.setEditorWindow(window)
                }
            )
            .onAppear {
                session.synchronizeDocumentText(document.text)
            }
            .onChange(of: document.text) { _, newValue in
                session.synchronizeDocumentText(newValue)
            }
            .onChange(of: session.text) { _, newValue in
                if document.text != newValue {
                    document.text = newValue
                }
            }
            .frame(minWidth: 960, minHeight: 700)
    }
}
