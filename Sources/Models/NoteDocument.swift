import SwiftUI
import UniformTypeIdentifiers

struct NoteDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.overlayMarkdown, .plainText]

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private extension UTType {
    static var overlayMarkdown: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }
}
